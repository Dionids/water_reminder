import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'health_service.dart';
import 'hive_service.dart';
import 'api_service.dart';

/// Имя фоновой задачи — должно быть уникальным
const _kBackgroundSyncTask = 'aquatrack.background_sync';

/// Минимальный интервал между любыми двумя синхронизациями (авто или ручная).
/// Защищает от двойных запросов если пользователь нажал Sync сразу после авто.
const _kMinSyncInterval = Duration(minutes: 5);

/// Интервал авто-синхронизации в фоне через WorkManager
const _kBackgroundSyncInterval = Duration(minutes: 15);

/// Порог "свежести" данных — если старше, показываем предупреждение
const _kDataStaleThreshold = Duration(hours: 1);

/// Точка входа для фоновой задачи WorkManager.
/// ВАЖНО: должна быть top-level функцией (не метод класса).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('WorkManager: запуск фоновой задачи "$taskName"');

    try {
      if (taskName == _kBackgroundSyncTask) {
        final hiveService = HiveService();
        await hiveService.init();

        final healthService = HealthService();
        final apiService = ApiService();

        // Проверяем разрешения без показа диалога
        final granted = await healthService.checkPermissions();
        if (!granted) {
          debugPrint('WorkManager: нет разрешений Health Connect, пропускаем');
          return true; // true = задача выполнена (не повторять немедленно)
        }

        final data = await healthService.fetchAllTodayData();
        final profile = hiveService.getProfile();
        final effectiveWeight = (data['weight'] as double) > 0
            ? data['weight'] as double
            : (profile?.weight ?? 70.0);

        final serverResponse = await apiService.syncActivity(
          firebaseUid: profile?.id ?? 'user_local',
          steps: data['steps'] as int,
          weightKg: effectiveWeight,
          workoutMinutes: data['workoutMinutes'] as int,
          workoutIntensity: data['workoutIntensity'] as WorkoutIntensity,
          activityNames: data['activityNames'] as List<String>,
          calories: (data['calories'] as double?) ?? 0.0,
          distanceM: (data['distance'] as double?) ?? 0.0,
        );

        if (serverResponse != null && profile != null) {
          final newGoal = serverResponse['daily_goal_ml'] as int?;
          if (newGoal != null) profile.dailyBaseGoal = newGoal;
          profile.lastSync = DateTime.now();
          await hiveService.saveProfile(profile);
          debugPrint('WorkManager: синхронизация успешна, норма = $newGoal мл');
        } else {
          // Офлайн — только обновляем время
          if (profile != null) {
            profile.lastSync = DateTime.now();
            await hiveService.saveProfile(profile);
          }
          debugPrint('WorkManager: офлайн, время синхронизации обновлено');
        }
      }
      return true;
    } catch (e) {
      debugPrint('WorkManager: ошибка — $e');
      return false; // false = задача провалилась, WorkManager может повторить
    }
  });
}

class SyncService {
  static bool _workmanagerInitialized = false;

  /// Инициализирует WorkManager. Вызывать один раз в main().
  static Future<void> initWorkManager() async {
    if (_workmanagerInitialized) return;
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    _workmanagerInitialized = true;
    debugPrint('WorkManager инициализирован');
  }

  /// Регистрирует периодическую фоновую задачу.
  /// WorkManager гарантирует выполнение даже если приложение закрыто.
  /// Минимальный интервал на Android — 15 минут (ограничение ОС).
  static Future<void> registerBackgroundSync() async {
    await Workmanager().registerPeriodicTask(
      _kBackgroundSyncTask,
      _kBackgroundSyncTask,
      frequency: _kBackgroundSyncInterval,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    debugPrint('WorkManager: фоновая синхронизация зарегистрирована');
  }

  /// Отменяет фоновую задачу (например при выходе из аккаунта).
  static Future<void> cancelBackgroundSync() async {
    await Workmanager().cancelByUniqueName(_kBackgroundSyncTask);
  }
}

/// Хелпер для проверки свежести данных и дедупликации — используется в UI.
class SyncState {
  final DateTime? lastSyncTime;
  final bool isSyncing;

  const SyncState({this.lastSyncTime, this.isSyncing = false});

  /// Данные считаются устаревшими если синхронизации не было более 1 часа
  bool get isStale {
    if (lastSyncTime == null) return true;
    return DateTime.now().difference(lastSyncTime!) > _kDataStaleThreshold;
  }

  /// Прошло ли достаточно времени для следующей синхронизации
  bool get canSync {
    if (isSyncing) return false;
    if (lastSyncTime == null) return true;
    return DateTime.now().difference(lastSyncTime!) > _kMinSyncInterval;
  }

  /// Человекочитаемая метка времени последней синхронизации
  String get label {
    if (lastSyncTime == null) return 'Не синхронизировано';
    final diff = DateTime.now().difference(lastSyncTime!);
    if (diff.inSeconds < 60) return 'Только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    return 'Вчера';
  }

  /// Цвет индикатора: серый → зелёный → жёлтый → красный
  SyncFreshness get freshness {
    if (lastSyncTime == null) return SyncFreshness.unknown;
    final diff = DateTime.now().difference(lastSyncTime!);
    if (diff.inMinutes < 30) return SyncFreshness.fresh;
    if (diff.inMinutes < 60) return SyncFreshness.aging;
    return SyncFreshness.stale;
  }
}

enum SyncFreshness { unknown, fresh, aging, stale }

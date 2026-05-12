import 'dart:io';
import 'package:flutter/services.dart';

/// Сервис синхронизации данных между Flutter-приложением и Wear OS часами.
///
/// Использует MethodChannel/EventChannel для общения с нативным Android-кодом,
/// который общается с часами через Wearable DataClient.
class WearSyncService {
  static const _methodChannel =
      MethodChannel('com.example.untitled1/wear_sync');
  static const _eventChannel =
      EventChannel('com.example.untitled1/wear_events');

  static final WearSyncService _instance = WearSyncService._();
  factory WearSyncService() => _instance;
  WearSyncService._();

  /// Stream событий "добавить воду" от часов или виджета.
  /// Эмитит количество мл которое нужно добавить.
  Stream<int> get watchAddWaterStream => _eventChannel
      .receiveBroadcastStream()
      .map((event) => (event as Map)['added_ml'] as int? ?? 250);

  /// Отправить актуальные данные на часы.
  /// [currentMl] — выпито сегодня, [goalMl] — дневная норма.
  Future<void> pushToWatch({
    required int currentMl,
    required int goalMl,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      await _methodChannel.invokeMethod('syncToWatch', {
        'current_ml': currentMl,
        'goal_ml': goalMl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      // Часы недоступны — не критично, данные уже в Hive
      print('[WearSync] Failed to sync to watch: ${e.message}');
    }
  }

  /// Отправить на часы запланированное напоминание выпить воду.
  ///
  /// [scheduledAt]  — время напоминания в миллисекундах (epoch)
  /// [glassIndex]   — номер текущего стакана (1-based)
  /// [totalGlasses] — всего стаканов за день
  Future<void> sendReminderToWatch({
    required int scheduledAt,
    required int glassIndex,
    required int totalGlasses,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      await _methodChannel.invokeMethod('scheduleWatchReminder', {
        'scheduled_at': scheduledAt,
        'glass_index': glassIndex,
        'total_glasses': totalGlasses,
      });
    } on PlatformException catch (e) {
      print('[WearSync] Failed to schedule reminder on watch: ${e.message}');
    }
  }
}

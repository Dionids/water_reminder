import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

enum WorkoutIntensity { none, low, medium, high, extreme }

class WorkoutSummaryData {
  final int totalMinutes;
  final WorkoutIntensity dominantIntensity;
  final List<String> activityNames;

  const WorkoutSummaryData({
    required this.totalMinutes,
    required this.dominantIntensity,
    required this.activityNames,
  });
}

class HealthService {
  final Health _health = Health();
  bool _configured = false;

  /// Кэш результата авторизации.
  /// На Android hasPermissions() ненадёжен — кэшируем результат requestAuthorization.
  bool _permissionsGranted = false;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.WEIGHT,
    HealthDataType.HEART_RATE,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WORKOUT,
  ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  // ── Разрешения ────────────────────────────────────────────────

  /// Запрашивает разрешения с диалогом. Вызывать только явно (ручной sync).
  Future<bool> requestPermissions() async {
    await _configure();
    final permissions = List.filled(_types.length, HealthDataAccess.READ);
    try {
      if (Platform.isAndroid) {
        await Permission.activityRecognition.request();
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          await _health.installHealthConnect();
          return false;
        }
      }
      final granted = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );
      _permissionsGranted = granted;
      debugPrint('Health permissions granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('Health requestPermissions error: $e');
      return false;
    }
  }

  /// Проверяет разрешения без диалога. Для авто-синхронизации.
  ///
  /// На Android [hasPermissions] ненадёжен (всегда null в некоторых версиях).
  /// Поэтому используем кэш из последнего [requestPermissions],
  /// а как fallback — пробуем прочитать шаги: если данные пришли, доступ есть.
  Future<bool> checkPermissions() async {
    await _configure();

    // Если уже авторизовывались в этой сессии — доверяем кэшу
    if (_permissionsGranted) return true;

    // Попытка через hasPermissions (может вернуть null на Android)
    try {
      final result = await _health.hasPermissions(_types);
      if (result != null) {
        _permissionsGranted = result;
        return result;
      }
    } catch (_) {}

    // Fallback: пробуем прочитать шаги — если 0 и нет ошибки, скорее всего доступ есть
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      await _health.getTotalStepsInInterval(start, now);
      _permissionsGranted = true;
      return true;
    } catch (e) {
      debugPrint('Health checkPermissions fallback error: $e');
      return false;
    }
  }

  // ── Главный метод: читает всё за сегодня параллельно ─────────

  Future<Map<String, dynamic>> fetchAllTodayData() async {
    await _configure();

    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    // Параллельные запросы
    final results = await Future.wait([
      getTodaySteps(),
      getLatestWeight(),
      getTodayCalories(),
      getLatestHeartRate(),
      getTodayDistance(startOfDay: startOfDay, now: now),
    ]);

    final steps     = results[0] as int;
    final weight    = results[1] as double;
    final calories  = results[2] as double;
    final heartRate = results[3] as int;
    var   distance  = results[4] as double;

    // Fallback дистанции через шаги (среднй шаг ~0.75м)
    if (distance == 0 && steps > 0) {
      distance = steps * 0.75;
      debugPrint('Distance: fallback from steps → ${distance.toInt()}м');
    }

    // Тренировки — после пульса (нужен для fallback интенсивности)
    final workout = await getTodayWorkoutSummary(
      avgHeartRate: heartRate,
      startOfDay: startOfDay,
      now: now,
    );

    debugPrint(
      'Health data: steps=$steps weight=$weight cal=${calories.toInt()} '
      'hr=$heartRate dist=${distance.toInt()}м '
      'workout=${workout.totalMinutes}мин ${workout.dominantIntensity.name}',
    );

    return {
      'steps':             steps,
      'weight':            weight,
      'calories':          calories,
      'heartRate':         heartRate,
      'distance':          distance,
      'workoutMinutes':    workout.totalMinutes,
      'workoutIntensity':  workout.dominantIntensity,
      'activityNames':     workout.activityNames,
    };
  }

  // ── Отдельные методы ──────────────────────────────────────────

  Future<int> getTodaySteps() async {
    await _configure();
    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      final steps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
      debugPrint('Steps: $steps');
      return steps;
    } catch (e) {
      debugPrint('Steps error: $e');
      return 0;
    }
  }

  Future<double> getLatestWeight() async {
    await _configure();
    final now = DateTime.now();
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startTime: now.subtract(const Duration(days: 365)),
        endTime: now,
      );
      if (data.isEmpty) return 0.0;

      // Явная сортировка — Health Connect не гарантирует порядок
      data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      final weight = _extractValue(data.last);
      debugPrint('Weight: ${weight}кг (из ${data.length} записей)');
      return weight;
    } catch (e) {
      debugPrint('Weight error: $e');
      return 0.0;
    }
  }

  Future<double> getTodayCalories() async {
    await _configure();
    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.TOTAL_CALORIES_BURNED],
        startTime: startOfDay,
        endTime: now,
      );

      // Дедупликация overlapping записей Samsung Health:
      // суммируем только неперекрывающиеся интервалы
      final total = _sumWithoutOverlap(data);
      debugPrint('Calories: ${total.toInt()} ккал (из ${data.length} записей)');
      return total;
    } catch (e) {
      debugPrint('Calories error: $e');
      return 0.0;
    }
  }

  Future<double> getTodayDistance({
    DateTime? startOfDay,
    DateTime? now,
  }) async {
    await _configure();
    final end   = now ?? DateTime.now();
    final start = startOfDay ?? DateTime(end.year, end.month, end.day);
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_DELTA],
        startTime: start,
        endTime: end,
      );
      final total = data.fold(0.0, (sum, p) => sum + _extractValue(p));
      debugPrint('Distance: ${total.toInt()}м (из ${data.length} записей)');
      return total;
    } catch (e) {
      debugPrint('Distance error: $e');
      return 0.0;
    }
  }

  Future<int> getLatestHeartRate() async {
    await _configure();
    final now = DateTime.now();
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        // Последний час — "текущий" пульс, 48ч слишком широко
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now,
      );
      if (data.isEmpty) {
        // Fallback: последние 24 часа если за час ничего нет
        final wider = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: now.subtract(const Duration(hours: 24)),
          endTime: now,
        );
        if (wider.isEmpty) return 0;
        wider.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        final hr = _extractValue(wider.last).toInt();
        debugPrint('HeartRate (24h fallback): $hr уд/мин');
        return hr;
      }
      // Явная сортировка
      data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      final hr = _extractValue(data.last).toInt();
      debugPrint('HeartRate: $hr уд/мин (из ${data.length} записей)');
      return hr;
    } catch (e) {
      debugPrint('HeartRate error: $e');
      return 0;
    }
  }

  Future<WorkoutSummaryData> getTodayWorkoutSummary({
    int avgHeartRate = 0,
    DateTime? startOfDay,
    DateTime? now,
  }) async {
    await _configure();
    final end   = now ?? DateTime.now();
    final start = startOfDay ?? DateTime(end.year, end.month, end.day);

    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: start,
        endTime: end,
      );

      debugPrint('Workouts: ${data.length} записей');

      if (data.isEmpty) {
        return const WorkoutSummaryData(
          totalMinutes: 0,
          dominantIntensity: WorkoutIntensity.none,
          activityNames: [],
        );
      }

      // FIX: используем секунды для точности, затем конвертируем
      int totalSeconds = 0;
      final intensities = <WorkoutIntensity>[];
      final names = <String>[];

      for (final point in data) {
        final durationSeconds =
            point.dateTo.difference(point.dateFrom).inSeconds;
        totalSeconds += durationSeconds;

        WorkoutIntensity intensity;
        String activityName;

        if (point.value is WorkoutHealthValue) {
          final wv = point.value as WorkoutHealthValue;
          activityName = _formatActivityName(wv.workoutActivityType);
          intensity    = _intensityFromActivityType(wv.workoutActivityType);

          // Samsung fallback: если OTHER и есть пульс — используем зоны ЧСС
          if (wv.workoutActivityType == HealthWorkoutActivityType.OTHER &&
              avgHeartRate > 0) {
            intensity = _intensityFromHeartRate(avgHeartRate);
          }
        } else {
          activityName = 'Тренировка';
          intensity    = avgHeartRate > 0
              ? _intensityFromHeartRate(avgHeartRate)
              : WorkoutIntensity.medium;
        }

        intensities.add(intensity);
        if (!names.contains(activityName)) names.add(activityName);

        debugPrint(
          'Workout: $activityName | '
          '${(durationSeconds / 60).round()} мин | '
          '${intensity.name}',
        );
      }

      final dominant =
          intensities.reduce((a, b) => a.index > b.index ? a : b);

      // Округляем секунды до минут (29:59 → 30 мин, не 29)
      final totalMinutes = (totalSeconds / 60).round();

      return WorkoutSummaryData(
        totalMinutes: totalMinutes,
        dominantIntensity: dominant,
        activityNames: names,
      );
    } catch (e) {
      debugPrint('Workout error: $e');
      return const WorkoutSummaryData(
        totalMinutes: 0,
        dominantIntensity: WorkoutIntensity.none,
        activityNames: [],
      );
    }
  }

  // ── Вспомогательные ──────────────────────────────────────────

  /// Суммирует значения без учёта перекрывающихся интервалов.
  /// Samsung Health иногда пишет дублирующие записи за один и тот же период.
  double _sumWithoutOverlap(List<HealthDataPoint> points) {
    if (points.isEmpty) return 0.0;

    // Сортируем по времени начала
    points.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    double total = 0.0;
    DateTime? lastEnd;

    for (final p in points) {
      if (lastEnd != null && p.dateFrom.isBefore(lastEnd)) {
        // Перекрывающийся интервал — пропускаем
        debugPrint(
          'Skipping overlapping record: ${p.dateFrom} – ${p.dateTo}',
        );
        continue;
      }
      total  += _extractValue(p);
      lastEnd = p.dateTo;
    }

    return total;
  }

  WorkoutIntensity _intensityFromActivityType(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.WALKING:
      case HealthWorkoutActivityType.YOGA:
      case HealthWorkoutActivityType.MIND_AND_BODY:
      case HealthWorkoutActivityType.FLEXIBILITY:
      case HealthWorkoutActivityType.PILATES:
      case HealthWorkoutActivityType.TAI_CHI:
      case HealthWorkoutActivityType.COOLDOWN:
      case HealthWorkoutActivityType.PREPARATION_AND_RECOVERY:
      case HealthWorkoutActivityType.GUIDED_BREATHING:
        return WorkoutIntensity.low;

      case HealthWorkoutActivityType.HIKING:
      case HealthWorkoutActivityType.DANCING:
      case HealthWorkoutActivityType.SOCIAL_DANCE:
      case HealthWorkoutActivityType.CARDIO_DANCE:
      case HealthWorkoutActivityType.GOLF:
      case HealthWorkoutActivityType.TENNIS:
      case HealthWorkoutActivityType.VOLLEYBALL:
      case HealthWorkoutActivityType.TABLE_TENNIS:
      case HealthWorkoutActivityType.BADMINTON:
      case HealthWorkoutActivityType.BOWLING:
      case HealthWorkoutActivityType.FISHING:
      case HealthWorkoutActivityType.ARCHERY:
        return WorkoutIntensity.medium;

      case HealthWorkoutActivityType.RUNNING:
      case HealthWorkoutActivityType.RUNNING_TREADMILL:
      case HealthWorkoutActivityType.BIKING:
      case HealthWorkoutActivityType.BIKING_STATIONARY:
      case HealthWorkoutActivityType.SWIMMING:
      case HealthWorkoutActivityType.SWIMMING_POOL:
      case HealthWorkoutActivityType.SWIMMING_OPEN_WATER:
      case HealthWorkoutActivityType.ELLIPTICAL:
      case HealthWorkoutActivityType.STAIR_CLIMBING:
      case HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE:
      case HealthWorkoutActivityType.BASKETBALL:
      case HealthWorkoutActivityType.SOCCER:
      case HealthWorkoutActivityType.RUGBY:
      case HealthWorkoutActivityType.HOCKEY:
      case HealthWorkoutActivityType.HANDBALL:
      case HealthWorkoutActivityType.CLIMBING:
      case HealthWorkoutActivityType.ROCK_CLIMBING:
      case HealthWorkoutActivityType.ROWING:
      case HealthWorkoutActivityType.ROWING_MACHINE:
      case HealthWorkoutActivityType.SKIING:
      case HealthWorkoutActivityType.CROSS_COUNTRY_SKIING:
      case HealthWorkoutActivityType.DOWNHILL_SKIING:
      case HealthWorkoutActivityType.SNOWBOARDING:
        return WorkoutIntensity.high;

      case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
      case HealthWorkoutActivityType.BOXING:
      case HealthWorkoutActivityType.KICKBOXING:
      case HealthWorkoutActivityType.MARTIAL_ARTS:
      case HealthWorkoutActivityType.JUMP_ROPE:
      case HealthWorkoutActivityType.CROSS_TRAINING:
      case HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING:
      case HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING:
      case HealthWorkoutActivityType.STRENGTH_TRAINING:
      case HealthWorkoutActivityType.WEIGHTLIFTING:
      case HealthWorkoutActivityType.CALISTHENICS:
      case HealthWorkoutActivityType.MIXED_CARDIO:
        return WorkoutIntensity.extreme;

      case HealthWorkoutActivityType.OTHER:
      default:
        return WorkoutIntensity.medium;
    }
  }

  WorkoutIntensity _intensityFromHeartRate(int bpm) {
    if (bpm < 100) return WorkoutIntensity.low;
    if (bpm < 130) return WorkoutIntensity.medium;
    if (bpm < 155) return WorkoutIntensity.high;
    return WorkoutIntensity.extreme;
  }

  String _formatActivityName(HealthWorkoutActivityType type) {
    return type.name.split('_').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  double _extractValue(HealthDataPoint p) {
    final val = p.value;
    if (val is NumericHealthValue) return val.numericValue.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Future<bool> isUserAsleep() async {
    await _configure();
    final now = DateTime.now();
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: now.subtract(const Duration(hours: 24)),
        endTime: now,
      );
      if (data.isEmpty) return false;
      return data.any(
        (p) => now.isAfter(p.dateFrom) && now.isBefore(p.dateTo),
      );
    } catch (e) {
      return false;
    }
  }
}

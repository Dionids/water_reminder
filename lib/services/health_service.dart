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
  // Кэш статуса разрешений — не спрашиваем каждые 30 минут
  bool? _permissionsGranted;
  DateTime? _permissionsCheckedAt;

  static const _permissionsCacheDuration = Duration(minutes: 10);

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.WEIGHT,
    HealthDataType.HEART_RATE,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WORKOUT,
  ];

  /// Запрашивает разрешения (показывает диалог).
  /// Вызывать только явно — при первом запуске или из настроек.
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
      final granted = await _health.requestAuthorization(_types, permissions: permissions);
      _permissionsGranted = granted;
      _permissionsCheckedAt = DateTime.now();
      debugPrint('Health permissions granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('Health requestPermissions error: $e');
      return false;
    }
  }

  /// Проверяет статус без показа диалога — для авто-синхронизации.
  /// Использует кэш чтобы не дёргать Health Connect лишний раз.
  Future<bool> checkPermissions() async {
    await _configure();

    // Кэш актуален — возвращаем без запроса
    final cached = _permissionsGranted;
    final checkedAt = _permissionsCheckedAt;
    if (cached != null && checkedAt != null &&
        DateTime.now().difference(checkedAt) < _permissionsCacheDuration) {
      return cached;
    }

    try {
      final granted = await _health.hasPermissions(_types) ?? false;
      _permissionsGranted = granted;
      _permissionsCheckedAt = DateTime.now();
      debugPrint('Health permissions check: $granted');
      return granted;
    } catch (e) {
      debugPrint('Health checkPermissions error: $e');
      return _permissionsGranted ?? false;
    }
  }

  /// Читает все данные за сегодня параллельно.
  /// Возвращает Map с результатами — удобно для одного await.
  Future<Map<String, dynamic>> fetchAllTodayData() async {
    await _configure();

    // Все независимые запросы — параллельно
    final results = await Future.wait([
      getTodaySteps(),
      getLatestWeight(),
      getTodayCalories(),
      getLatestHeartRate(),
      getTodayDistance(),
    ]);

    final steps     = results[0] as int;
    final weight    = results[1] as double;
    final calories  = results[2] as double;
    final heartRate = results[3] as int;
    var   distance  = results[4] as double;

    // Fallback дистанции через шаги — тоже параллельно было бы, но нужны шаги
    if (distance == 0 && steps > 0) {
      distance = steps * 0.75;
    }

    // Тренировки — зависят от пульса, идут последними
    final workout = await getTodayWorkoutSummary(avgHeartRate: heartRate);

    return {
      'steps':            steps,
      'weight':           weight,
      'calories':         calories,
      'heartRate':        heartRate,
      'distance':         distance,
      'workoutMinutes':   workout.totalMinutes,
      'workoutIntensity': workout.dominantIntensity,
      'activityNames':    workout.activityNames,
    };
  }

  Future<int> getTodaySteps() async {
    await _configure();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      return await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
    } catch (e) {
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
      return _extractValue(data.last);
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> getTodayCalories() async {
    await _configure();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.TOTAL_CALORIES_BURNED],
        startTime: startOfDay,
        endTime: now,
      );
      return data.fold(0.0, (sum, p) => sum + _extractValue(p));
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> getTodayDistance({int? fallbackSteps}) async {
    await _configure();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_DELTA],
        startTime: startOfDay,
        endTime: now,
      );
      final total = data.fold(0.0, (sum, p) => sum + _extractValue(p));
      if (total == 0 && fallbackSteps != null) return fallbackSteps * 0.75;
      return total;
    } catch (e) {
      if (fallbackSteps != null) return fallbackSteps * 0.75;
      return 0.0;
    }
  }

  Future<int> getLatestHeartRate() async {
    await _configure();
    final now = DateTime.now();
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: now.subtract(const Duration(hours: 48)),
        endTime: now,
      );
      if (data.isEmpty) return 0;
      return _extractValue(data.last).toInt();
    } catch (e) {
      return 0;
    }
  }

  Future<WorkoutSummaryData> getTodayWorkoutSummary({int avgHeartRate = 0}) async {
    await _configure();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: startOfDay,
        endTime: now,
      );

      if (data.isEmpty) {
        return const WorkoutSummaryData(
          totalMinutes: 0,
          dominantIntensity: WorkoutIntensity.none,
          activityNames: [],
        );
      }

      int totalMinutes = 0;
      final intensities = <WorkoutIntensity>[];
      final names = <String>[];

      for (final point in data) {
        totalMinutes += point.dateTo.difference(point.dateFrom).inMinutes;

        WorkoutIntensity intensity;
        String activityName;

        if (point.value is WorkoutHealthValue) {
          final wv = point.value as WorkoutHealthValue;
          activityName = _formatActivityName(wv.workoutActivityType);
          intensity = _intensityFromActivityType(wv.workoutActivityType);
          if (wv.workoutActivityType == HealthWorkoutActivityType.OTHER && avgHeartRate > 0) {
            intensity = _intensityFromHeartRate(avgHeartRate);
          }
        } else {
          activityName = 'Тренировка';
          intensity = avgHeartRate > 0 ? _intensityFromHeartRate(avgHeartRate) : WorkoutIntensity.medium;
        }

        intensities.add(intensity);
        if (!names.contains(activityName)) names.add(activityName);
      }

      final dominant = intensities.reduce((a, b) => a.index > b.index ? a : b);
      return WorkoutSummaryData(
        totalMinutes: totalMinutes,
        dominantIntensity: dominant,
        activityNames: names,
      );
    } catch (e) {
      debugPrint('Workout fetch error: $e');
      return const WorkoutSummaryData(
        totalMinutes: 0,
        dominantIntensity: WorkoutIntensity.none,
        activityNames: [],
      );
    }
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
      return data.any((p) => now.isAfter(p.dateFrom) && now.isBefore(p.dateTo));
    } catch (e) {
      return false;
    }
  }
}

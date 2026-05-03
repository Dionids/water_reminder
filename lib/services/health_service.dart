import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Интенсивность тренировки — определяет бонус к норме воды
enum WorkoutIntensity { none, low, medium, high, extreme }

/// Сводка по тренировкам за день
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

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> requestPermissions() async {
    await _configure();

    final types = [
      HealthDataType.STEPS,
      HealthDataType.WEIGHT,
      HealthDataType.HEART_RATE,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.WORKOUT,
    ];

    final permissions = List.filled(types.length, HealthDataAccess.READ);

    try {
      if (Platform.isAndroid) {
        await Permission.activityRecognition.request();
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          await _health.installHealthConnect();
          return false;
        }
      }

      final bool authorized = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      debugPrint('Health Auth Status: $authorized');
      return authorized;
    } catch (e) {
      debugPrint('Health Service Authorization Error: $e');
      return false;
    }
  }

  Future<int> getTodaySteps() async {
    await _configure();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      final steps = await _health.getTotalStepsInInterval(startOfDay, now);
      debugPrint('Steps: $steps');
      return steps ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<double> getLatestWeight() async {
    await _configure();
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 365));
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startTime: start,
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
      double total = 0.0;
      for (var p in data) {
        total += _extractValue(p);
      }
      return total;
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
      double total = 0.0;
      for (var p in data) {
        total += _extractValue(p);
      }
      if (total == 0 && fallbackSteps != null) {
        return fallbackSteps * 0.75;
      }
      return total;
    } catch (e) {
      if (fallbackSteps != null) return fallbackSteps * 0.75;
      return 0.0;
    }
  }

  Future<int> getLatestHeartRate() async {
    await _configure();
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 48));
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: now,
      );
      if (data.isEmpty) return 0;
      return _extractValue(data.last).toInt();
    } catch (e) {
      return 0;
    }
  }

  /// Классификация по MET (стандарт ВОЗ) — UPPER_CASE константы health ^13.x
  WorkoutIntensity _intensityFromActivityType(HealthWorkoutActivityType type) {
    switch (type) {
      // Низкая интенсивность — MET 1.5–3
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

      // Средняя интенсивность — MET 3–6
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

      // Высокая интенсивность — MET 6–9
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

      // Очень высокая — MET > 9
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

      // OTHER — Samsung Health fallback на пульс
      case HealthWorkoutActivityType.OTHER:
      default:
        return WorkoutIntensity.medium;
    }
  }

  /// Fallback: зоны ЧСС
  WorkoutIntensity _intensityFromHeartRate(int bpm) {
    if (bpm < 100) return WorkoutIntensity.low;
    if (bpm < 130) return WorkoutIntensity.medium;
    if (bpm < 155) return WorkoutIntensity.high;
    return WorkoutIntensity.extreme;
  }

  String _formatActivityName(HealthWorkoutActivityType type) {
    final words = type.name.split('_').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
    return words;
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

      debugPrint('Workouts today: ${data.length}');

      if (data.isEmpty) {
        return const WorkoutSummaryData(
          totalMinutes: 0,
          dominantIntensity: WorkoutIntensity.none,
          activityNames: [],
        );
      }

      int totalMinutes = 0;
      final List<WorkoutIntensity> intensities = [];
      final List<String> names = [];

      for (final point in data) {
        final durationMinutes = point.dateTo.difference(point.dateFrom).inMinutes;
        totalMinutes += durationMinutes;

        WorkoutIntensity intensity;
        String activityName;

        if (point.value is WorkoutHealthValue) {
          final wv = point.value as WorkoutHealthValue;
          activityName = _formatActivityName(wv.workoutActivityType);
          intensity = _intensityFromActivityType(wv.workoutActivityType);

          // Fallback на пульс для Samsung OTHER
          if (wv.workoutActivityType == HealthWorkoutActivityType.OTHER &&
              avgHeartRate > 0) {
            intensity = _intensityFromHeartRate(avgHeartRate);
          }
        } else {
          activityName = 'Тренировка';
          intensity = avgHeartRate > 0
              ? _intensityFromHeartRate(avgHeartRate)
              : WorkoutIntensity.medium;
        }

        intensities.add(intensity);
        if (!names.contains(activityName)) names.add(activityName);
        debugPrint('Workout: $activityName | $durationMinutes мин | $intensity');
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

  double _extractValue(HealthDataPoint p) {
    final val = p.value;
    if (val is NumericHealthValue) return val.numericValue.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Future<bool> isUserAsleep() async {
    await _configure();
    final now = DateTime.now();
    final startOfCheck = now.subtract(const Duration(hours: 24));
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: startOfCheck,
        endTime: now,
      );
      if (data.isEmpty) return false;
      for (var p in data) {
        if (now.isAfter(p.dateFrom) && now.isBefore(p.dateTo)) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

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
      debugPrint('Steps count: $steps');
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
      debugPrint('Weight data points: ${data.length}');
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
      debugPrint('Calories data points: ${data.length}');
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
        debugPrint('Distance is 0, using fallback calculation from steps');
        return fallbackSteps * 0.75;
      }

      debugPrint('Distance data points: ${data.length}, total: $total');
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
      debugPrint('HeartRate data points: ${data.length}');
      if (data.isEmpty) return 0;
      return _extractValue(data.last).toInt();
    } catch (e) {
      return 0;
    }
  }

  /// Получает тренировки за сегодня и возвращает сводку:
  /// общее время + доминирующая интенсивность + названия активностей.
  ///
  /// Интенсивность определяется по типу активности (MET по стандарту ВОЗ).
  /// Fallback: если Samsung вернул OTHER — используем средний пульс.
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

          // Fallback на пульс если Samsung вернул OTHER
          if (wv.workoutActivityType == HealthWorkoutActivityType.other &&
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

      // Доминирующая интенсивность = максимальная за день
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

  /// Классификация по MET (Metabolic Equivalent of Task) — стандарт ВОЗ
  WorkoutIntensity _intensityFromActivityType(HealthWorkoutActivityType type) {
    switch (type) {
      // Низкая интенсивность — MET 1.5–3
      case HealthWorkoutActivityType.walking:
      case HealthWorkoutActivityType.yoga:
      case HealthWorkoutActivityType.mindAndBody:
      case HealthWorkoutActivityType.flexibility:
      case HealthWorkoutActivityType.stretching:
      case HealthWorkoutActivityType.pilates:
        return WorkoutIntensity.low;

      // Средняя интенсивность — MET 3–6
      case HealthWorkoutActivityType.hiking:
      case HealthWorkoutActivityType.dancing:
      case HealthWorkoutActivityType.tennis:
      case HealthWorkoutActivityType.volleyball:
      case HealthWorkoutActivityType.golf:
        return WorkoutIntensity.medium;

      // Высокая интенсивность — MET 6–9
      case HealthWorkoutActivityType.running:
      case HealthWorkoutActivityType.cycling:
      case HealthWorkoutActivityType.swimming:
      case HealthWorkoutActivityType.elliptical:
      case HealthWorkoutActivityType.stairClimbing:
      case HealthWorkoutActivityType.basketball:
      case HealthWorkoutActivityType.soccer:
      case HealthWorkoutActivityType.rugby:
        return WorkoutIntensity.high;

      // Очень высокая — MET > 9
      case HealthWorkoutActivityType.rowing:
      case HealthWorkoutActivityType.crossFit:
      case HealthWorkoutActivityType.boxing:
      case HealthWorkoutActivityType.martialArts:
      case HealthWorkoutActivityType.jumpRope:
      case HealthWorkoutActivityType.highIntensityIntervalTraining:
        return WorkoutIntensity.extreme;

      // Samsung Health обычно возвращает OTHER — fallback на пульс
      case HealthWorkoutActivityType.other:
      default:
        return WorkoutIntensity.medium;
    }
  }

  /// Fallback: определение интенсивности по среднему пульсу (зоны ЧСС)
  WorkoutIntensity _intensityFromHeartRate(int bpm) {
    if (bpm < 100) return WorkoutIntensity.low;
    if (bpm < 130) return WorkoutIntensity.medium;
    if (bpm < 155) return WorkoutIntensity.high;
    return WorkoutIntensity.extreme;
  }

  String _formatActivityName(HealthWorkoutActivityType type) {
    final raw = type.name;
    final spaced = raw.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}').trim();
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  double _extractValue(HealthDataPoint p) {
    final val = p.value;
    if (val is NumericHealthValue) {
      return val.numericValue.toDouble();
    }
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
        if (now.isAfter(p.dateFrom) && now.isBefore(p.dateTo)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}

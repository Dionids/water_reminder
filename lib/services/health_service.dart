import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

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

  /// Получает калории от упражнений (TotalCaloriesBurnedRecord в Health Connect / Samsung Health)
  Future<double> getTodayCalories() async {
    await _configure();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      // Для Samsung Health используем только TOTAL_CALORIES_BURNED, 
      // так как это соответствует Exercise Calories
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.TOTAL_CALORIES_BURNED],
        startTime: startOfDay,
        endTime: now,
      );
      debugPrint('Exercise Calories data points: ${data.length}');
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
      
      // Проверяем, попадает ли текущее время в интервал какой-либо записи о сне
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

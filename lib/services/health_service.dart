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
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.TOTAL_CALORIES_BURNED, // Добавили общий расход
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

  Future<double> getTodayCalories() async {
    await _configure();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      // Пытаемся получить и активные, и общие калории
      final data = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.TOTAL_CALORIES_BURNED
        ],
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

  Future<double> getTodayDistance() async {
    await _configure();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_DELTA],
        startTime: startOfDay,
        endTime: now,
      );
      debugPrint('Distance data points: ${data.length}');
      double total = 0.0;
      for (var p in data) {
        total += _extractValue(p);
      }
      return total;
    } catch (e) {
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
      return data.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

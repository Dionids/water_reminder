import 'dart:io';

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
      HealthDataType.SLEEP_ASLEEP,
    ];

    final permissions = [
      HealthDataAccess.READ,
      HealthDataAccess.READ,
    ];

    try {
      if (Platform.isAndroid) {
        final activityRecognition = await Permission.activityRecognition.request();
        if (!activityRecognition.isGranted) {
          return false;
        }

        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          await _health.installHealthConnect();
          return false;
        }
      }

      return _health.requestAuthorization(
        types,
        permissions: permissions,
      );
    } catch (e) {
      print('Health Service Authorization Error: $e');
      return false;
    }
  }

  Future<int> getTodaySteps() async {
    await _configure();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final steps = await _health.getTotalStepsInInterval(startOfDay, now);
      return steps ?? 0;
    } catch (e) {
      print('Health Service Error (Steps): $e');
      return 0;
    }
  }

  Future<bool> isUserAsleep() async {
    await _configure();

    final now = DateTime.now();
    final startOfCheck = now.subtract(const Duration(hours: 24));

    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: startOfCheck,
        endTime: now,
      );
      return healthData.isNotEmpty;
    } catch (e) {
      print('Health Service Error (Sleep): $e');
      return false;
    }
  }
}
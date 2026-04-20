import 'package:health/health.dart';
import 'dart:io';

class HealthService {
  final Health _health = Health();

  Future<bool> requestPermissions() async {
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
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          await _health.installHealthConnect();
          return false;
        }
      }

      // Запрашиваем авторизацию. 
      // На Android 14+ это автоматически должно открыть системное окно Health Connect,
      // если манифест настроен правильно (а мы его настроили).
      bool authorized = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      
      return authorized;
    } catch (e) {
      print('Health Service Authorization Error: $e');
      return false;
    }
  }

  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    try {
      // Прямое чтение из Health Connect
      final steps = await _health.getTotalStepsInInterval(startOfDay, now);
      return steps ?? 0;
    } catch (e) {
      print('Health Service Error (Steps): $e');
      return 0;
    }
  }

  Future<bool> isUserAsleep() async {
    final now = DateTime.now();
    final startOfCheck = now.subtract(const Duration(hours: 24));

    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
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

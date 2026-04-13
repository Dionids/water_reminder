import 'package:health/health.dart';

class HealthService {
  final Health health = Health();

  Future<bool> requestPermissions() async {
    var types = [HealthDataType.STEPS, HealthDataType.SLEEP_ASLEEP];
    // В новых версиях permissions передаются иначе или не требуются явно в этом методе
    return await health.requestAuthorization(types);
  }

  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    try {
      final steps = await health.getTotalStepsInInterval(startOfDay, now);
      return steps ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> isUserAsleep() async {
    final now = DateTime.now();
    final startOfCheck = now.subtract(const Duration(minutes: 30));

    try {
      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: startOfCheck,
        endTime: now,
      );
      return healthData.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

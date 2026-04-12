import 'package:health/health.dart';

class HealthService {
  final HealthFactory health = HealthFactory();

  // Define the types of data we want to read
  final List<HealthDataType> types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WORKOUT,
  ];

  // Request permissions from the user
  Future<bool> requestPermissions() async {
    // On Android, this will trigger the Health Connect/Google Fit dialog
    // On iOS, this will trigger the HealthKit dialog
    return await health.requestAuthorization(types);
  }

  // Fetch steps for the current day
  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day);

    try {
      int? steps = await health.getTotalStepsInInterval(yesterday, now);
      return steps ?? 0;
    } catch (e) {
      print("Error fetching steps: $e");
      return 0;
    }
  }

  // Check if user is currently asleep (based on the last 30 minutes)
  Future<bool> isUserAsleep() async {
    final now = DateTime.now();
    final thirtyMinsAgo = now.subtract(const Duration(minutes: 30));

    try {
      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        thirtyMinsAgo,
        now,
        [HealthDataType.SLEEP_ASLEEP],
      );
      // If there's an active "asleep" record in the last 30 mins, assume they are sleeping
      return healthData.isNotEmpty;
    } catch (e) {
      print("Error fetching sleep data: $e");
      return false;
    }
  }
}

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/water_log.dart';
import '../models/user_profile.dart';
import '../models/activity_cache.dart';

class IsarService {
  late Isar isar;

  IsarService._(this.isar);

  static Future<IsarService> build() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [WaterLogSchema, UserProfileSchema, ActivityCacheSchema],
      directory: dir.path,
    );
    return IsarService._(isar);
  }

  // --- Water Log Operations ---

  Future<void> addWater(int amount) async {
    final log = WaterLog(
      amountMl: amount,
      dateTime: DateTime.now(),
      type: 'water',
    );
    await isar.writeTxn(() async {
      await isar.waterLogs.put(log);
    });
  }

  Future<int> getTodayTotalWater() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final logs = await isar.waterLogs
        .filter()
        .dateTimeBetween(startOfDay, endOfDay)
        .findAll();

    // Исправлено: явное приведение типов
    int total = 0;
    for (final log in logs) {
      total += log.amountMl ?? 0;
    }
    return total;
  }

  Future<int> getWaterForDay(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final logs = await isar.waterLogs
        .filter()
        .dateTimeBetween(startOfDay, endOfDay)
        .findAll();

    // Исправлено: явное приведение типов
    int total = 0;
    for (final log in logs) {
      total += log.amountMl ?? 0;
    }
    return total;
  }

  // --- User Profile ---

  Future<void> saveProfile(double weight, int age) async {
    final profile = UserProfile(
      weight: weight,
      age: age,
      dailyBaseGoal: (weight * 30).toInt(),
    );

    await isar.writeTxn(() async {
      await isar.userProfiles.clear();
      await isar.userProfiles.put(profile);
    });
  }

  Future<UserProfile?> getProfile() async {
    return await isar.userProfiles.where().findFirst();
  }

  // --- Activity Cache ---

  Future<void> updateActivityCache(int steps, int workoutMinutes, bool isAsleep) async {
    final cache = ActivityCache(
      steps: steps,
      workoutMinutes: workoutMinutes,
      isAsleep: isAsleep,
      date: DateTime.now(),
    );

    await isar.writeTxn(() async {
      await isar.activityCaches.clear();
      await isar.activityCaches.put(cache);
    });
  }
}


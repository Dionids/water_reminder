import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';
import '../models/water_log.dart';
import '../models/activity_cache.dart';

class IsarService {
  late Isar isar;

  IsarService._create(this.isar);

  static Future<IsarService> build() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [UserProfileSchema, WaterLogSchema, ActivityCacheSchema],
      directory: dir.path,
    );
    return IsarService._create(isar);
  }

  // --- Water Log Operations ---

  Future<void> addWater(int amount) async {
    final log = WaterLog(
      amountMl: amount,
      dateTime: DateTime.now(),
    );
    await isar.writeTxn(() => isar.waterLogs.put(log));
  }

  // --- User Profile ---

  Future<void> saveProfile(double weight, int age) async {
    final profile = UserProfile()
      ..weight = weight
      ..age = age
      ..dailyBaseGoal = (weight * 30).toInt();

    await isar.writeTxn(() async {
      await isar.userProfiles.clear();
      await isar.userProfiles.put(profile);
    });
  }

  Future<UserProfile?> getProfile() async {
    return await isar.userProfiles.where().findFirst();
  }

  Future<List<WaterLog>> getTodayLogs() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return await isar.waterLogs
        .filter()
        .dateTimeGreaterThan(todayStart)
        .findAll();
  }

  Future<int> getTodayTotalWater() async {
    final logs = await getTodayLogs();
    return logs.fold(0, (sum, item) => sum + item.amountMl);
  }

  // --- Profile Operations ---

  Future<UserProfile?> getUserProfile() async {
    return await isar.userProfiles.where().findFirst();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await isar.writeTxn(() => isar.userProfiles.put(profile));
  }

  // --- Activity Cache Operations ---

  Future<void> updateActivityCache(int steps, int workoutMinutes, bool isAsleep) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final cache = ActivityCache(
      date: today,
      steps: steps,
      workoutMinutes: workoutMinutes,
      isAsleep: isAsleep,
    );
    
    await isar.writeTxn(() => isar.activityCaches.put(cache));
  }

  Future<ActivityCache?> getTodayActivity() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return await isar.activityCaches.filter().dateEqualTo(today).findFirst();
  }
}

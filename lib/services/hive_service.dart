import 'package:hive_flutter/hive_flutter.dart';
import '../models/water_log.dart';
import '../models/user_profile.dart';

class HiveService {
  static const String waterBoxName = 'water_logs';
  static const String profileBoxName = 'user_profile';

  Future<void> init() async {
    await Hive.initFlutter();
    
    // Регистрация адаптеров (они будут сгенерированы позже)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(WaterLogAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserProfileAdapter());
    }

    await Hive.openBox<WaterLog>(waterBoxName);
    await Hive.openBox<UserProfile>(profileBoxName);
  }

  // --- Water Logs ---

  Future<void> addWaterLog(double amount) async {
    final box = Hive.box<WaterLog>(waterBoxName);
    final log = WaterLog(
      amount: amount,
      date: DateTime.now(),
    );
    await box.add(log);
  }

  Future<double> getTotalWaterToday() async {
    final box = Hive.box<WaterLog>(waterBoxName);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final logsToday = box.values.where((log) => log.date.isAfter(today));
    
    double total = 0;
    for (var log in logsToday) {
      total += log.amount;
    }
    return total;
  }

  Future<List<WaterLog>> getAllLogs() async {
    final box = Hive.box<WaterLog>(waterBoxName);
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> deleteLog(int index) async {
    final box = Hive.box<WaterLog>(waterBoxName);
    await box.deleteAt(index);
  }

  // --- User Profile ---

  Future<void> saveProfile(UserProfile profile) async {
    final box = Hive.box<UserProfile>(profileBoxName);
    await box.put('current_profile', profile);
  }

  UserProfile? getProfile() {
    final box = Hive.box<UserProfile>(profileBoxName);
    return box.get('current_profile');
  }

  // Вспомогательный метод для совместимости с кодом, который ожидал Stream от Isar
  Stream<void> watchWater() {
    return Hive.box<WaterLog>(waterBoxName).watch();
  }
}

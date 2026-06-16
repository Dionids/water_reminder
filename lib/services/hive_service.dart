import 'package:hive_flutter/hive_flutter.dart';
import '../models/water_log.dart';
import '../models/user_profile.dart';

class HiveService {
  static const String waterBoxName   = 'water_logs';
  static const String profileBoxName = 'user_profile';

  Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(WaterLogAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserProfileAdapter());
    }

    await Hive.openBox<WaterLog>(waterBoxName);
    await Hive.openBox<UserProfile>(profileBoxName);
  }

  // ── Water Logs ───────────────────────────────────────────────────

  /// Добавляет лог локально. synced=false — попадёт в офлайн-очередь.
  Future<WaterLog> addWaterLog(double amount) async {
    final box = Hive.box<WaterLog>(waterBoxName);
    final log = WaterLog(
      amount: amount,
      date:   DateTime.now(),
      synced: false,
    );
    await box.add(log);
    return log;
  }

  /// Добавляет лог восстановленный с сервера. synced=true — не нужно повторно отправлять.
  Future<WaterLog> addWaterLogFromServer({
    required double amount,
    required DateTime date,
  }) async {
    final box = Hive.box<WaterLog>(waterBoxName);
    // Проверяем дубликаты по времени с точностью до минуты
    final existingKey = box.keys.firstWhere(
      (k) {
        final log = box.get(k);
        if (log == null) return false;
        final diff = log.date.difference(date).inSeconds.abs();
        return diff < 60 && (log.amount - amount).abs() < 1;
      },
      orElse: () => null,
    );
    if (existingKey != null) return box.get(existingKey)!;

    final log = WaterLog(amount: amount, date: date, synced: true);
    await box.add(log);
    return log;
  }

  /// Помечает лог как синхронизированный с сервером.
  Future<void> markLogSynced(WaterLog log) async {
    log.synced = true;
    await log.save();
  }

  /// Возвращает все несинхронизированные логи (офлайн-очередь).
  List<WaterLog> getUnsyncedLogs() {
    final box = Hive.box<WaterLog>(waterBoxName);
    return box.values.where((l) => !l.synced).toList();
  }

  Future<double> getTotalWaterToday() async {
    final box   = Hive.box<WaterLog>(waterBoxName);
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    double total = 0.0;
    for (final log in box.values) {
      // isAfter(today) пропускает записи ровно в полночь — используем !isBefore
      if (!log.date.isBefore(today)) total += log.amount;
    }
    return total;
  }

  Future<List<WaterLog>> getAllLogs() async {
    final box = Hive.box<WaterLog>(waterBoxName);
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── User Profile ─────────────────────────────────────────────────

  Future<void> saveProfile(UserProfile profile) async {
    final box = Hive.box<UserProfile>(profileBoxName);
    await box.put('current_profile', profile);
  }

  UserProfile? getProfile() {
    final box = Hive.box<UserProfile>(profileBoxName);
    return box.get('current_profile');
  }

  Future<void> clearProfile() async {
    final box = Hive.box<UserProfile>(profileBoxName);
    await box.delete('current_profile');
  }

  Stream<void> watchWater() {
    return Hive.box<WaterLog>(waterBoxName).watch();
  }
}

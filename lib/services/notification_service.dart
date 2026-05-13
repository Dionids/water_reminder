import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'hive_service.dart';
import 'health_service.dart';
import 'wear_sync_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final HiveService hiveService;
  final HealthService healthService;

  static const int _glassMl        = 250;
  static const int _reminderIdBase = 100;
  static const int _maxReminders   = 100;

  NotificationService({required this.hiveService, required this.healthService});

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(settings);

    // Запрашиваем разрешение на показ уведомлений (Android 13+)
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Умное разовое напоминание ──────────────────────────────────────

  Future<void> showHydrationReminder({required int dailyGoal}) async {
    try {
      final currentWater = await hiveService.getTotalWaterToday();
      if (currentWater >= dailyGoal) return;
      final isAsleep = await healthService.isUserAsleep();
      if (isAsleep) return;

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'hydration_id',
        'Напоминания о воде',
        channelDescription: 'Напоминает выпить воду на основе активности',
        importance: Importance.high,
        priority: Priority.high,
      );
      await _notifications.show(
        0,
        '💧 Время выпить воду!',
        'Выпито ${((currentWater / dailyGoal) * 100).toInt()}% нормы.',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('NotificationService.showHydrationReminder error: $e');
    }
  }

  // ── Планировщик по расписанию сна ─────────────────────────────────

  /// Отменяет старые напоминания и планирует новые.
  /// Стаканы равномерно распределяются между [wakeTime] и [bedTime].
  /// Каждое напоминание также отправляется на часы через [WearSyncService].
  Future<void> scheduleDailyWaterReminders({
    required DateTime wakeTime,
    required DateTime bedTime,
    required int goalMl,
  }) async {
    try {
      // Отменяем старые напоминания
      for (var i = _reminderIdBase; i < _reminderIdBase + _maxReminders; i++) {
        await _notifications.cancel(i);
      }

      final glasses = (goalMl / _glassMl).ceil().clamp(1, _maxReminders);
      final wakingMinutes = bedTime.difference(wakeTime).inMinutes;
      if (wakingMinutes <= 0) {
        debugPrint('scheduleDailyWaterReminders: invalid sleep window, skip');
        return;
      }

      final intervalMinutes = (wakingMinutes / glasses).round();
      final now = DateTime.now();

      for (var i = 0; i < glasses; i++) {
        final scheduledTime =
            wakeTime.add(Duration(minutes: intervalMinutes * i));

        // Не планируем напоминания в прошлом
        if (scheduledTime.isBefore(now)) continue;

        final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

        final androidDetails = AndroidNotificationDetails(
          'water_reminders',
          'Напоминания по расписанию',
          channelDescription: 'Напоминает выпить стакан воды по расписанию сна',
          importance: Importance.high,
          priority: Priority.high,
          // FLAG_ONLY_ALERT_ONCE — перекидывает уведомление на часы
          additionalFlags: Int32List.fromList([0x00000020]),
        );

        await _notifications.zonedSchedule(
          _reminderIdBase + i,
          '💧 Выпей стакан воды',
          'Стакан ${i + 1} из $glasses · осталось ${glasses - i - 1}',
          tzScheduled,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );

        // Отправляем расписание на часы
        try {
          await WearSyncService().sendReminderToWatch(
            scheduledAt: scheduledTime.millisecondsSinceEpoch,
            glassIndex:  i + 1,
            totalGlasses: glasses,
          );
        } catch (e) {
          debugPrint('sendReminderToWatch[$i] error: $e');
        }
      }

      debugPrint(
          'scheduleDailyWaterReminders: $glasses стаканов запланировано '
          '(${wakeTime.hour}:${wakeTime.minute.toString().padLeft(2, '0')} – '
          '${bedTime.hour}:${bedTime.minute.toString().padLeft(2, '0')})');
    } catch (e) {
      debugPrint('scheduleDailyWaterReminders error: $e');
    }
  }
}

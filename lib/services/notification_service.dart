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
  }

  // Умное разовое напоминание
  Future<void> showHydrationReminder({required int dailyGoal}) async {
    try {
      final currentWater = await hiveService.getTotalWaterToday();
      if (currentWater >= dailyGoal) return;
      final isAsleep = await healthService.isUserAsleep();
      if (isAsleep) return;

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'hydration_id',
        'Hydration Reminders',
        channelDescription: 'Reminds you to drink water based on your activity',
        importance: Importance.high,
        priority: Priority.high,
      );
      await _notifications.show(
        0,
        'Время выпить воду!',
        'Выпито ${((currentWater / dailyGoal) * 100).toInt()}% нормы.',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Notification Service Error: $e');
    }
  }

  // Планировщик по расписанию сна
  Future<void> scheduleDailyWaterReminders({
    required DateTime wakeTime,
    required DateTime bedTime,
    required int goalMl,
  }) async {
    for (var i = _reminderIdBase; i < _reminderIdBase + _maxReminders; i++) {
      await _notifications.cancel(i);
    }

    final now = DateTime.now();
    if (bedTime.isBefore(now)) {
      debugPrint('Reminders: окно бодрствования прошло.');
      return;
    }

    final startTime =
        wakeTime.isBefore(now) ? now.add(const Duration(minutes: 2)) : wakeTime;
    final wakeDuration = bedTime.difference(startTime);
    if (wakeDuration.inMinutes < 30) return;

    final glasses         = (goalMl / _glassMl).ceil();
    final intervalMinutes = wakeDuration.inMinutes / glasses;
    int scheduled         = 0;

    debugPrint('Reminders: $glasses стаканов, интервал ${intervalMinutes.round()} мин');

    for (var i = 0; i < glasses && scheduled < _maxReminders; i++) {
      final reminderTime =
          startTime.add(Duration(minutes: (intervalMinutes * i).round()));
      if (reminderTime.isBefore(now) || reminderTime.isAfter(bedTime)) continue;

      final remaining = glasses - i;
      final timeStr =
          '${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, "0")}';

      try {
        await _notifications.zonedSchedule(
          _reminderIdBase + scheduled,
          'Выпей стакан воды',
          'Стакан ${i + 1} из $glasses, осталось $remaining ($timeStr)',
          tz.TZDateTime.from(reminderTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'water_schedule',
              'График воды по сну',
              channelDescription: 'Напоминания по времени бодрствования',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              additionalFlags: Int32List.fromList([0x00000020]),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );

        WearSyncService().sendReminderToWatch(
          scheduledAt:  reminderTime.millisecondsSinceEpoch,
          glassIndex:   i + 1,
          totalGlasses: glasses,
        );

        debugPrint('  -> #${_reminderIdBase + scheduled} в $timeStr');
        scheduled++;
      } catch (e) {
        debugPrint('  -> ошибка #$i: $e');
      }
    }
    debugPrint('Reminders: запланировано $scheduled уведомлений.');
  }

  Future<void> requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
}

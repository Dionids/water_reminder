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

  /// Объём одного стакана в мл
  static const int _glassMl = 250;

  /// Базовый ID для запланированных напоминаний (IDs 100–199)
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

  // ── Умное разовое напоминание ─────────────────────────────────

  Future<void> showHydrationReminder({required int dailyGoal}) async {
    try {
      final currentWater = await hiveService.getTotalWaterToday();
      if (currentWater >= dailyGoal) {
        debugPrint('Smart Notification: цель достигнута, пропускаем.');
        return;
      }

      final isAsleep = await healthService.isUserAsleep();
      if (isAsleep) {
        debugPrint('Smart Notification: пользователь спит, пропускаем.');
        return;
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'hydration_id',
        'Hydration Reminders',
        channelDescription:
            'Reminds you to drink water based on your activity',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _notifications.show(
        0,
        '💧 Время выпить воду!',
        'Выпито ${((currentWater / dailyGoal) * 100).toInt()}% �
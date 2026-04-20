import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'hive_service.dart';
import 'health_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final HiveService hiveService;
  final HealthService healthService;

  NotificationService({required this.hiveService, required this.healthService});

  Future<void> init() async {
    tz_data.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
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

  // Smart check before showing notification
  Future<void> showHydrationReminder({required int dailyGoal}) async {
    // 1. Check progress
    final currentWater = await hiveService.getTotalWaterToday();
    if (currentWater >= dailyGoal) {
      print('Smart Notification: Goal already reached. Skipping.');
      return;
    }

    // 2. Check sleep status
    final isAsleep = await healthService.isUserAsleep();
    if (isAsleep) {
      print('Smart Notification: User is asleep. Skipping.');
      return;
    }

    // 3. Show notification
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'hydration_id',
      'Hydration Reminders',
      channelDescription: 'Reminds you to drink water based on your activity',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0,
      'Time to drink water! 💧',
      'You have reached only ${((currentWater / dailyGoal) * 100).toInt()}% of your goal.',
      details,
    );
  }

  Future<void> requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
}

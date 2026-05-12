import 'dart:io';
import 'package:flutter/services.dart';

/// Сервис синхронизации данных между Flutter-приложением и Wear OS часами.
///
/// Использует MethodChannel для вызова нативного кода Android,
/// который общается с часами через Wearable DataClient.
///
/// Вызывай [pushToWatch] после каждого добавления воды или пересчёта нормы.
class WearSyncService {
  static const _channel = MethodChannel('com.example.untitled1/wear_sync');

  static final WearSyncService _instance = WearSyncService._();
  factory WearSyncService() => _instance;
  WearSyncService._();

  /// Отправить актуальные данные на часы.
  /// [currentMl] — выпито сегодня, [goalMl] — дневная норма.
  Future<void> pushToWatch({
    required int currentMl,
    required int goalMl,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('syncToWatch', {
        'current_ml': currentMl,
        'goal_ml': goalMl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      // Часы недоступны — не критично, данные уже в Hive
      print('[WearSync] Failed to sync to watch: ${e.message}');
    }
  }

  /// Отправить на часы запланированное напоминание выпить воду.
  ///
  /// [scheduledAt]  — время напоминания в миллисекундах (epoch)
  /// [glassIndex]   — номер текущего стакана (1-based)
  /// [totalGlasses] — всего стаканов за день
  Future<void> sendReminderToWatch({
    required int scheduledAt,
    required int glassIndex,
    required in
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Реальный WearSyncService — общается с нативным WearSyncChannel.kt
/// через MethodChannel (телефон → часы) и EventChannel (часы → телефон).
class WearSyncService {
  static final WearSyncService _instance = WearSyncService._();
  factory WearSyncService() => _instance;
  WearSyncService._();

  static const _method = MethodChannel('com.dionids.aquatrack/wear_sync');
  static const _event  = EventChannel('com.dionids.aquatrack/wear_events');

  Stream<int>? _watchStream;

  /// Stream событий «добавить воду» с часов.
  /// Испускает количество добавленных мл когда пользователь нажал + на часах.
  Stream<int> get watchAddWaterStream {
    _watchStream ??= _event
        .receiveBroadcastStream()
        .map((event) {
          if (event is Map) return (event['added_ml'] as int?) ?? 250;
          return 250;
        })
        .handleError((e) {
          debugPrint('WearSyncService event error: $e');
        });
    return _watchStream!;
  }

  /// Отправить текущий прогресс на часы — обновляет плитку и экран часов.
  Future<void> pushToWatch({
    required int currentMl,
    required int goalMl,
  }) async {
    try {
      await _method.invokeMethod('syncToWatch', {
        'current_ml': currentMl,
        'goal_ml':    goalMl,
        'timestamp':  DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      // Часы не подключены — не критично
      debugPrint('WearSyncService.pushToWatch: $e');
    }
  }

  /// Отправить расписание напоминания на часы.
  Future<void> sendReminderToWatch({
    required int scheduledAt,
    required int glassIndex,
    required int totalGlasses,
  }) async {
    try {
      await _method.invokeMethod('scheduleWatchReminder', {
        'scheduled_at':  scheduledAt,
        'glass_index':   glassIndex,
        'total_glasses': totalGlasses,
      });
    } catch (e) {
      debugPrint('WearSyncService.sendReminderToWatch: $e');
    }
  }
}

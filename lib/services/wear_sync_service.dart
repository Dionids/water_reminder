import 'dart:async';
import 'package:flutter/foundation.dart';

/// Заглушка WearSyncService.
/// Wear OS интеграция не реализована — все методы no-op,
/// Stream не генерирует событий.
/// Когда понадобится реальная Wear OS — заменить на wear + wearable_communication.
class WearSyncService {
  static final WearSyncService _instance = WearSyncService._();
  factory WearSyncService() => _instance;
  WearSyncService._();

  /// Stream событий «добавить воду» с часов.
  /// Заглушка — никогда не испускает значений.
  Stream<int> get watchAddWaterStream => const Stream<int>.empty();

  /// Отправить текущий прогресс на часы.
  Future<void> pushToWatch({
    required int currentMl,
    required int goalMl,
  }) async {
    debugPrint('WearSyncService.pushToWatch (stub): $currentMl / $goalMl мл');
  }

  /// Отправить расписание напоминания на часы.
  Future<void> sendReminderToWatch({
    required int scheduledAt,
    required int glassIndex,
    required int totalGlasses,
  }) async {
    debugPrint(
      'WearSyncService.sendReminderToWatch (stub): '
      'glass $glassIndex/$totalGlasses at $scheduledAt',
    );
  }
}

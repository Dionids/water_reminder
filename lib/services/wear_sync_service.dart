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

  /// Слушать события от часов (нажатие + на часах).
  /// Вернёт Stream с количеством мл, которые часы просят добавить.
  Stream<int> get watchAddWaterStream {
    if (!Platform.isAndroid) return const Stream.empty();
    return const EventChannel('com.example.untitled1/wear_events')
        .receiveBroadcastStream()
        .map((event) => (event as Map)['added_ml'] as int? ?? 200);
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'health_service.dart';

class ApiService {
  // В продакшене заменить на реальный URL
  // Для эмулятора: 10.0.2.2, для физического устройства: IP компьютера
  final String baseUrl = 'http://10.0.2.2:8000';

  /// Конвертирует enum интенсивности в строку для API
  String _intensityToString(WorkoutIntensity intensity) {
    switch (intensity) {
      case WorkoutIntensity.none:    return 'none';
      case WorkoutIntensity.low:     return 'low';
      case WorkoutIntensity.medium:  return 'medium';
      case WorkoutIntensity.high:    return 'high';
      case WorkoutIntensity.extreme: return 'extreme';
    }
  }

  /// Отправляет данные активности на сервер и получает пересчитанную норму воды.
  /// Возвращает null при ошибке сети (работаем с локальными данными).
  Future<Map<String, dynamic>?> syncActivity({
    required String userId,
    required int steps,
    required double weightKg,
    int workoutMinutes = 0,
    WorkoutIntensity workoutIntensity = WorkoutIntensity.none,
    List<String> activityNames = const [],
  }) async {
    try {
      final body = {
        'user_id': userId,
        'steps': steps,
        'weight_kg': weightKg,
        'workout_minutes': workoutMinutes,
        'workout_intensity': _intensityToString(workoutIntensity),
        'activity_names': activityNames,
      };

      debugPrint('ApiService → syncActivity: $body');

      final response = await http
          .post(
            Uri.parse('$baseUrl/sync-activity'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('ApiService ← response: $result');
        return result;
      } else {
        debugPrint('ApiService: server error ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('ApiService: network error — $e');
      return null;
    }
  }
}

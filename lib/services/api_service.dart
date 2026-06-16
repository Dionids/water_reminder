import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'health_service.dart';

class ApiService {
  // URL выбирается по приоритету:
  // 1. Переменная окружения API_BASE_URL (передаётся через --dart-define при сборке)
  // 2. В debug-режиме: 10.0.2.2 (эмулятор) или Railway (физическое устройство)
  // 3. Прод Railway URL как финальный fallback
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://lovely-trust-production-ad76.up.railway.app',
  );

  String get baseUrl => _baseUrl;

  final _client = http.Client();

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('ApiService $path: HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ApiService $path: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl$path'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('ApiService GET $path: $e');
      return null;
    }
  }

  /// Регистрация / обновление пользователя на сервере.
  /// Вызывается после Firebase Auth (вход или обновление профиля).
  Future<void> upsertUser({
    required String firebaseUid,
    String? deviceId,
    String? displayName,
    String? email,
    bool isAnonymous = true,
    double? weightKg,
    int? age,
  }) async {
    await _post('/user', {
      'firebase_uid': firebaseUid,
      if (deviceId != null)     'device_id':    deviceId,
      if (displayName != null)  'display_name': displayName,
      if (email != null)        'email':        email,
      'is_anonymous':            isAnonymous,
      if (weightKg != null)     'weight_kg':    weightKg,
      if (age != null)          'age':          age,
    });
  }

  /// Синхронизация активности + получение пересчитанной нормы.
  Future<Map<String, dynamic>?> syncActivity({
    required String firebaseUid,
    required int steps,
    required double weightKg,
    int workoutMinutes = 0,
    WorkoutIntensity workoutIntensity = WorkoutIntensity.none,
    List<String> activityNames = const [],
    double calories = 0,
    double distanceM = 0,
    DateTime? logDate,
  }) async {
    return _post('/sync-activity', {
      'firebase_uid':      firebaseUid,
      'steps':             steps,
      'weight_kg':         weightKg,
      'workout_minutes':   workoutMinutes,
      'workout_intensity': _intensityToString(workoutIntensity),
      'activity_names':    activityNames,
      'calories':          calories,
      'distance_m':        distanceM,
      if (logDate != null)
        'log_date': '${logDate.year}-${logDate.month.toString().padLeft(2,'0')}-${logDate.day.toString().padLeft(2,'0')}',
    });
  }

  /// Сохранение записи о выпитой воде на сервере.
  Future<void> logWater({
    required String firebaseUid,
    required double amountMl,
    DateTime? loggedAt,
  }) async {
    await _post('/water-log', {
      'firebase_uid': firebaseUid,
      'amount_ml':    amountMl,
      if (loggedAt != null) 'logged_at': loggedAt.toIso8601String(),
    });
  }

  /// Аналитика за N дней.
  Future<Map<String, dynamic>?> getAnalytics(String firebaseUid, {int days = 7}) async {
    return _get('/analytics/$firebaseUid?days=$days');
  }

  /// Логи воды за дату с сервера (для восстановления на новом устройстве).
  /// [date] — в формате 'yyyy-MM-dd', по умолчанию сегодня.
  Future<Map<String, dynamic>?> getWaterLogs(String firebaseUid, {String? date}) async {
    final query = date != null ? '?date=$date' : '';
    return _get('/water-logs/$firebaseUid$query');
  }

  String _intensityToString(WorkoutIntensity intensity) {
    switch (intensity) {
      case WorkoutIntensity.none:    return 'none';
      case WorkoutIntensity.low:     return 'low';
      case WorkoutIntensity.medium:  return 'medium';
      case WorkoutIntensity.high:    return 'high';
      case WorkoutIntensity.extreme: return 'extreme';
    }
  }
}

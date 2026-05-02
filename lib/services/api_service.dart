import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // 10.0.2.2 is the special IP to access localhost from Android Emulator
  final String baseUrl = 'http://10.0.2.2:8000';

  Future<Map<String, dynamic>?> syncActivity({
    required String userId,
    required int steps,
    required int workoutMinutes,
    double weight = 70.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync-activity'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'steps': steps,
          'workout_minutes': workoutMinutes,
          'weight_kg': weight,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Server error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Network error: $e');
      return null;
    }
  }
}

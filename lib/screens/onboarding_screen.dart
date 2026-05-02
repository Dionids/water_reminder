import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../models/user_profile.dart';

class OnboardingScreen extends StatefulWidget {
  final HiveService hiveService;
  const OnboardingScreen({super.key, required this.hiveService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  Future<void> _saveProfile() async {
    final weight = double.tryParse(_weightController.text) ?? 70.0;
    final age = int.tryParse(_ageController.text) ?? 25;

    // Базовая норма по формуле ВОЗ — 30 мл/кг.
    // После первой синхронизации с Health Connect будет пересчитана сервером.
    final baseGoal = (weight * 30).toInt();

    // Генерируем уникальный ID пользователя на основе времени
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    final profile = UserProfile(
      weight: weight,
      age: age,
      dailyBaseGoal: baseGoal,
      userId: userId,
    );

    await widget.hiveService.saveProfile(profile);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройка профиля')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Введите данные для расчёта\nнормы воды',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Вес (кг)',
                prefixIcon: Icon(Icons.monitor_weight),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Возраст',
                prefixIcon: Icon(Icons.cake),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Начать', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Text(
              'Базовая норма: вес × 30 мл\n'
              'Будет скорректирована после синхронизации с Health Connect',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

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
    
    final profile = UserProfile(
      weight: weight,
      age: age,
      dailyBaseGoal: (weight * 35).toInt(), // Simple formula: 35ml per kg
    );

    await widget.hiveService.saveProfile(profile);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: "Weight (kg)"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: "Age"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text("Save and Start"),
            ),
          ],
        ),
      ),
    );
  }
}

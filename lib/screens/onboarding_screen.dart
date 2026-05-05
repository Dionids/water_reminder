import 'package:flutter/material.dart';
import '../services/hive_service.dart';

class OnboardingScreen extends StatefulWidget {
  final HiveService hiveService;

  const OnboardingScreen({
    super.key,
    required this.hiveService,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _weightController = TextEditingController();
  final _ageController    = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final weight = double.tryParse(_weightController.text);
    final age    = int.tryParse(_ageController.text);

    if (weight == null || weight <= 0 || weight > 300) {
      _showError('Введите корректный вес (1–300 кг)');
      return;
    }
    if (age == null || age < 5 || age > 120) {
      _showError('Введите корректный возраст (5–120 лет)');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Профиль уже создан AuthService при входе — обновляем только вес и возраст
      final profile = widget.hiveService.getProfile();
      if (profile != null) {
        profile.weight        = weight;
        profile.age           = age;
        profile.dailyBaseGoal = (weight * 30).toInt(); // ВОЗ, уточнится после синхронизации
        await widget.hiveService.saveProfile(profile);
      }

      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.hiveService.getProfile();
    final name    = profile?.displayName;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Приветствие
                    if (name != null)
                      Text(
                        'Привет, $name! 👋',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      )
                    else
                      const Text(
                        'Расскажи о себе',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),

                    const SizedBox(height: 8),
                    Text(
                      'Для точного расчёта нормы воды',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 32),

                    // Вес
                    _InputCard(
                      controller: _weightController,
                      label: 'Вес (кг)',
                      hint: 'Например: 70',
                      icon: Icons.monitor_weight_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    // Возраст
                    _InputCard(
                      controller: _ageController,
                      label: 'Возраст',
                      hint: 'Например: 25',
                      icon: Icons.cake_rounded,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 24),

                    // Превью нормы
                    _buildGoalPreview(),

                    const SizedBox(height: 28),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Начать',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Норма уточнится после синхронизации\nс Health Connect',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGoalPreview() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    if (weight <= 0) return const SizedBox.shrink();
    final goal = (weight * 30).toInt();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop_rounded, color: Color(0xFF1565C0)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Базовая норма воды',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
              Text('$goal мл / день',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1565C0))),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _InputCard({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

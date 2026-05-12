import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../services/health_service.dart';

class OnboardingScreen extends StatefulWidget {
  final HiveService hiveService;
  final HealthService? healthService;

  const OnboardingScreen({
    super.key,
    required this.hiveService,
    this.healthService,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _weightController = TextEditingController();
  final _ageController    = TextEditingController();
  bool _isLoading         = false;
  bool _isFetchingHealth  = false;
  double? _healthWeight;
  bool _weightFromHealth  = false;

  @override
  void initState() {
    super.initState();
    _tryFetchHealthWeight();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  /// Пытаемся получить вес из Health Connect без диалога разрешений.
  /// Если нашли — подставляем в поле, пользователь может просто нажать «Начать».
  Future<void> _tryFetchHealthWeight() async {
    final hs = widget.healthService;
    if (hs == null) return;

    setState(() => _isFetchingHealth = true);
    try {
      // Сначала пробуем без диалога (checkPermissions)
      final hasPerms = await hs.checkPermissions();
      double weight = 0;
      if (hasPerms) {
        weight = await hs.getLatestWeight();
      } else {
        // Запрашиваем разрешения — пользователь только что авторизовался,
        // самый подходящий момент
        final granted = await hs.requestPermissions();
        if (granted) {
          weight = await hs.getLatestWeight();
        }
      }

      if (weight > 0 && mounted) {
        setState(() {
          _healthWeight   = weight;
          _weightFromHealth = true;
          _weightController.text = weight.toStringAsFixed(1);
        });
      }
    } catch (e) {
      debugPrint('Onboarding: health weight fetch error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingHealth = false);
    }
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
      final profile = widget.hiveService.getProfile();
      if (profile != null) {
        profile.weight        = weight;
        profile.age           = age;
        profile.dailyBaseGoal = (weight * 30).toInt();
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // Иконка воды
                    Center(
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1565C0).withOpacity(0.3),
                              blurRadius: 16, offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: const Icon(Icons.water_drop_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Приветствие
                    Text(
                      name != null ? 'Привет, $name! 👋' : 'Расскажи о себе',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Для точного расчёта нормы воды',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),

                    const SizedBox(height: 24),

                    // Статус Health Connect
                    _buildHealthStatus(),

                    const SizedBox(height: 16),

                    // Вес
                    _InputCard(
                      controller: _weightController,
                      label: 'Вес (кг)',
                      hint: 'Например: 70',
                      icon: Icons.monitor_weight_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      suffixWidget: _weightFromHealth
                          ? const Tooltip(
                              message: 'Получено из Health Connect',
                              child: Icon(Icons.health_and_safety_rounded,
                                  size: 18, color: Color(0xFF43A047)),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Возраст
                    _InputCard(
                      controller: _ageController,
                      label: 'Возраст',
                      hint: 'Например: 25',
                      icon: Icons.cake_rounded,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 20),

                    // Превью нормы
                    _buildGoalPreview(),

                    const SizedBox(height: 24),

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
                        child: Text(
                          _weightFromHealth ? 'Начать' : 'Начать',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Норма уточнится после синхронизации\nс Health Connect',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHealthStatus() {
    if (_isFetchingHealth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Получаем вес из Health Connect...',
                style: TextStyle(fontSize: 13, color: Color(0xFF1565C0))),
          ],
        ),
      );
    }

    if (_weightFromHealth && _healthWeight != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 18, color: Color(0xFF43A047)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Вес получен из Health Connect: '
                '${_healthWeight!.toStringAsFixed(1)} кг',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
      );
    }

    // Health Connect недоступен или нет данных — тихо скрываем
    return const SizedBox.shrink();
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
                  style: TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
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
  final Widget? suffixWidget;

  const _InputCard({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    this.onChanged,
    this.suffixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8),
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
          suffixIcon:
              suffixWidget != null ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffixWidget,
              ) : null,
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

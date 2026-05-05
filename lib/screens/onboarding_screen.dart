import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';

class OnboardingScreen extends StatefulWidget {
  final HiveService hiveService;
  final AuthService authService;

  const OnboardingScreen({
    super.key,
    required this.hiveService,
    required this.authService,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _weightController = TextEditingController();
  final _ageController    = TextEditingController();

  bool _isLoading = false;
  int _step = 0; // 0 = выбор входа, 1 = ввод данных

  AuthResult? _authResult;

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // ── Шаг 1: Анонимный вход ─────────────────────────────────────────────────

  Future<void> _continueAnonymously() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.authService.signInAnonymously();
      if (!mounted) return;
      if (result != null) {
        setState(() { _authResult = result; _step = 1; });
      } else {
        _showError('Не удалось войти. Проверьте интернет-соединение.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Шаг 1: Google Sign-In ─────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.authService.signInWithGoogle();
      if (!mounted) return;
      if (result != null) {
        setState(() { _authResult = result; _step = 1; });
      } else {
        _showError('Google Sign-In отменён или не удался.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Шаг 2: Сохранение профиля ─────────────────────────────────────────────

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
      final auth = _authResult!;
      final profile = UserProfile(
        weight:        weight,
        age:           age,
        dailyBaseGoal: (weight * 30).toInt(), // ВОЗ, уточнится после синхронизации
        firebaseUid:   auth.userId,
        deviceId:      auth.deviceId,
        displayName:   auth.displayName,
        email:         auth.email,
        isAnonymous:   auth.isAnonymous,
      );

      await widget.hiveService.saveProfile(profile);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _step == 0
                ? _buildAuthStep()
                : _buildProfileStep(),
      ),
    );
  }

  // ── UI: Шаг 1 — выбор входа ───────────────────────────────────────────────

  Widget _buildAuthStep() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          // Логотип
          Container(
            width: 90, height: 90,
            alignment: Alignment.center,
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
                  blurRadius: 20, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 44),
          ),

          const SizedBox(height: 28),
          const Text(
            'AquaTrack',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 8),
          Text(
            'Умный трекер воды с учётом\nвашей активности',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4),
          ),

          const Spacer(),

          // Google Sign-In
          _GoogleButton(onTap: _signInWithGoogle),

          const SizedBox(height: 12),

          // Анонимный вход
          OutlinedButton(
            onPressed: _continueAnonymously,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Продолжить без входа',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Вход через Google сохраняет историю\nпри смене устройства',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── UI: Шаг 2 — данные профиля ────────────────────────────────────────────

  Widget _buildProfileStep() {
    final auth = _authResult!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // Приветствие
          if (!auth.isAnonymous && auth.displayName != null)
            Text(
              'Привет, ${auth.displayName}! 👋',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            )
          else
            const Text(
              'Расскажи о себе',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),

          const SizedBox(height: 8),
          Text(
            'Для точного расчёта нормы воды',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          // Вес
          _InputCard(
            controller: _weightController,
            label: 'Вес (кг)',
            hint: 'Например: 70',
            icon: Icons.monitor_weight_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Начать', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 12),
          Text(
            'Норма уточнится после синхронизации\nс Health Connect',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
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
                  style: TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
              Text('$goal мл / день',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://www.google.com/favicon.ico',
                width: 20, height: 20,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.login, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Войти через Google',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _InputCard({
    required this.controller, required this.label,
    required this.hint, required this.icon,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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

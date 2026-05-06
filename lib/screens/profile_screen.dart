import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../services/health_service.dart';
import '../services/auth_service.dart';
import '../services/home_widget_service.dart';

class ProfileScreen extends StatefulWidget {
  final HiveService hiveService;
  final HealthService healthService;
  final AuthService authService;

  const ProfileScreen({
    super.key,
    required this.hiveService,
    required this.healthService,
    required this.authService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _weightController;
  late TextEditingController _ageController;
  bool _isSaving = false;
  bool _isLoadingFromHealth = false;
  double? _healthWeight;

  @override
  void initState() {
    super.initState();
    final profile = widget.hiveService.getProfile();
    _weightController = TextEditingController(
      text: profile?.weight?.toStringAsFixed(1) ?? '',
    );
    _ageController = TextEditingController(
      text: profile?.age?.toString() ?? '',
    );
    _tryLoadWeightFromHealth();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _tryLoadWeightFromHealth() async {
    setState(() => _isLoadingFromHealth = true);
    try {
      final w = await widget.healthService.getLatestWeight();
      if (w > 0 && mounted) setState(() => _healthWeight = w);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingFromHealth = false);
  }

  Future<void> _addHomeWidget() async {
    // Обновляем данные в виджете
    final profile = widget.hiveService.getProfile();
    final totalMl = await widget.hiveService.getTotalWaterToday();
    await HomeWidgetService().update(
      currentMl: totalMl,
      goalMl: (profile?.dailyBaseGoal ?? 2000).toDouble(),
    );

    if (!mounted) return;
    // Показываем инструкцию — Android не разрешает добавлять виджет программно
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Добавить виджет'),
        content: const Text(
          'Зажмите пустое место на домашнем экране → '
          'нажмите «Виджеты» → найдите AquaTrack → '
          'перетащите на экран.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _addWearTile() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Карточка на Wear OS'),
        content: const Text(
          '1. Установите AquaTrack на часы через Android Studio\n\n'
          '2. Откройте приложение на часах — появится диалог добавления карточки\n\n'
          'Или: Galaxy Wearable → Карточки → + → AquaTrack',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    final weight = double.tryParse(_weightController.text);
    final age = int.tryParse(_ageController.text);

    if (weight == null || weight <= 0) {
      _showError('Введите корректный вес');
      return;
    }
    if (age == null || age <= 0 || age > 120) {
      _showError('Введите корректный возраст');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = widget.hiveService.getProfile();
      if (profile != null) {
        profile.weight = weight;
        profile.age = age;
        // Пересчитываем базовую норму — сервер уточнит при след. синхронизации
        profile.dailyBaseGoal = (weight * 30).toInt();
        await widget.hiveService.saveProfile(profile);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Профиль сохранён'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    final currentGoal = profile?.dailyBaseGoal ?? 0;
    final previewWeight = double.tryParse(_weightController.text) ?? 0;
    final previewGoal = previewWeight > 0 ? (previewWeight * 30).toInt() : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4F8),
        elevation: 0,
        title: const Text('Профиль', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Аватар-заглушка ────────────────────────────────
            Center(
              child: Container(
                width: 80,
                height: 80,
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
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 24),

            // ── Карточка данных ────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Личные данные',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 16),

                  // Вес
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Вес (кг)',
                      prefixIcon: const Icon(Icons.monitor_weight_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  // Подсказка с весом из Health Connect
                  if (_isLoadingFromHealth)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                        SizedBox(width: 8),
                        Text('Загружаем вес из Health Connect...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    )
                  else if (_healthWeight != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () {
                          _weightController.text = _healthWeight!.toStringAsFixed(1);
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.health_and_safety_rounded,
                                  size: 14, color: Color(0xFF1565C0)),
                              const SizedBox(width: 6),
                              Text(
                                'Health Connect: ${_healthWeight!.toStringAsFixed(1)} кг — нажмите чтобы применить',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Возраст
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Возраст',
                      prefixIcon: const Icon(Icons.cake_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Предпросмотр нормы ─────────────────────────────
            if (previewGoal > 0)
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Базовая норма воды',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _NormChip(
                            label: 'Было',
                            value: currentGoal > 0 ? '$currentGoal мл' : '—',
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NormChip(
                            label: 'Будет',
                            value: '$previewGoal мл',
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Норма вес × 30 мл. Точно пересчитается\nпри следующей синхронизации с Health Connect.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // ── Аккаунт ────────────────────────────────────────
            _buildAccountCard(),

            const SizedBox(height: 12),

            // ── Виджеты ────────────────────────────────────────
            _QuickActionCard(
              icon: Icons.widgets_rounded,
              title: 'Виджет на экране',
              subtitle: 'Прогресс воды прямо на рабочем столе',
              btnLabel: 'Добавить',
              onTap: _addHomeWidget,
            ),
            const SizedBox(height: 10),
            _QuickActionCard(
              icon: Icons.watch_rounded,
              title: 'Карточка на часах',
              subtitle: 'Wear OS — уровень воды на запястье',
              btnLabel: 'Настроить',
              onTap: _addWearTile,
            ),

            const SizedBox(height: 20),

            // ── Кнопка сохранить ───────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Сохранить',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    final profile = widget.hiveService.getProfile();
    final isAnonymous = profile?.isAnonymous ?? true;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Аккаунт',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),

          if (!isAnonymous) ...[
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_circle_rounded,
                    color: Color(0xFF1565C0), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile?.displayName ?? 'Пользователь',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (profile?.email != null)
                    Text(profile!.email!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Google',
                    style: TextStyle(fontSize: 11,
                        color: Color(0xFF43A047), fontWeight: FontWeight.w600)),
              ),
            ]),
          ] else ...[
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline_rounded,
                    color: Colors.grey.shade500, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Гостевой аккаунт',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('История не сохраняется при смене устройства',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              )),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await widget.authService.signInWithGoogle();
                  if (result.success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Аккаунт привязан к Google ✓')),
                    );
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Привязать Google аккаунт'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 4),

          // Выход
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Выйти',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Выйти из аккаунта?'),
                  content: const Text(
                      'Локальные данные останутся на устройстве.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Выйти',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await widget.authService.signOut();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}

class _NormChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _NormChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String btnLabel;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.icon, required this.title,
    required this.subtitle, required this.btnLabel, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1565C0), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: Text(btnLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

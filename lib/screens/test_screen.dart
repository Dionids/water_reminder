import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/hive_service.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';

/// Экран «Тест» — ручной ввод всех метрик для демонстрации комиссии.
/// Позволяет задать шаги, вес, тренировку, сон, воду без Health Connect.
class TestScreen extends StatefulWidget {
  final HiveService hiveService;
  final ApiService apiService;

  const TestScreen({
    super.key,
    required this.hiveService,
    required this.apiService,
  });

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  // ── Контроллеры ввода ─────────────────────────────────────────
  final _stepsCtrl         = TextEditingController(text: '8000');
  final _weightCtrl        = TextEditingController();
  final _caloriesCtrl      = TextEditingController(text: '450');
  final _distanceCtrl      = TextEditingController(text: '6.0');
  final _heartRateCtrl     = TextEditingController(text: '72');
  final _workoutMinsCtrl   = TextEditingController(text: '45');
  final _sleepHoursCtrl    = TextEditingController(text: '7.5');
  final _waterAmountCtrl   = TextEditingController(text: '250');

  WorkoutIntensity _intensity = WorkoutIntensity.medium;
  String _activityName = 'Бег';
  DateTime _selectedDate = DateTime.now(); // дата для исторических данных

  // ── Результаты после отправки ─────────────────────────────────
  bool   _isLoading     = false;
  String? _lastAdvice;
  int?    _goalMl;
  int?    _baseMl;
  int?    _stepsMl;
  int?    _workoutMl;
  String? _errorMsg;
  String? _successMsg;

  static const _activities = [
    'Бег', 'Ходьба', 'Велосипед', 'Плавание',
    'HIIT', 'Йога', 'Кроссфит', 'Баскетбол',
    'Танцы', 'Теннис', 'Боксирование', 'Скакалка',
  ];

  static const _intensityLabels = {
    WorkoutIntensity.none:    'Нет тренировки',
    WorkoutIntensity.low:     'Низкая (ходьба, йога)',
    WorkoutIntensity.medium:  'Средняя (танцы, теннис)',
    WorkoutIntensity.high:    'Высокая (бег, велосипед)',
    WorkoutIntensity.extreme: 'Экстремальная (HIIT, кроссфит)',
  };

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  String get _dateLabel {
    if (_isToday) return 'Сегодня';
    final d = _selectedDate;
    final months = ['янв','фев','мар','апр','май','июн',
                    'июл','авг','сен','окт','ноя','дек'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'Выберите дату',
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  void initState() {
    super.initState();
    final profile = widget.hiveService.getProfile();
    if (profile?.weight != null) {
      _weightCtrl.text = profile!.weight!.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _stepsCtrl.dispose();
    _weightCtrl.dispose();
    _caloriesCtrl.dispose();
    _distanceCtrl.dispose();
    _heartRateCtrl.dispose();
    _workoutMinsCtrl.dispose();
    _sleepHoursCtrl.dispose();
    _waterAmountCtrl.dispose();
    super.dispose();
  }

  // ── Отправка активности на сервер ────────────────────────────
  Future<void> _sendActivity() async {
    final profile = widget.hiveService.getProfile();
    if (profile == null) {
      setState(() => _errorMsg = 'Профиль не найден. Пройдите онбординг.');
      return;
    }

    final steps    = int.tryParse(_stepsCtrl.text)        ?? 0;
    final weight   = double.tryParse(_weightCtrl.text)    ?? 70.0;
    final calories = double.tryParse(_caloriesCtrl.text)  ?? 0.0;
    final distance = (double.tryParse(_distanceCtrl.text) ?? 0.0) * 1000; // км → м
    final mins     = int.tryParse(_workoutMinsCtrl.text)  ?? 0;

    setState(() { _isLoading = true; _errorMsg = null; _successMsg = null; });

    try {
      // Обновляем вес в профиле и на сервере
      if (weight > 0) {
        profile.weight = weight;
        profile.dailyBaseGoal = (weight * 30).toInt();
        await widget.hiveService.saveProfile(profile);

        if (profile.firebaseUid != null) {
          await widget.apiService.upsertUser(
            firebaseUid: profile.firebaseUid!,
            deviceId:    profile.deviceId,
            displayName: profile.displayName,
            email:       profile.email,
            isAnonymous: profile.isAnonymous,
            weightKg:    weight,
            age:         profile.age,
          );
        }
      }

      final activityNames = _intensity != WorkoutIntensity.none && mins > 0
          ? [_activityName]
          : <String>[];

      final result = await widget.apiService.syncActivity(
        firebaseUid:      profile.id,
        steps:            steps,
        weightKg:         weight,
        workoutMinutes:   mins,
        workoutIntensity: _intensity,
        activityNames:    activityNames,
        calories:         calories,
        distanceM:        distance,
        logDate:          _isToday ? null : _selectedDate,
      );

      if (!mounted) return;

      if (result != null) {
        // Обновляем цель в профиле
        final newGoal = result['daily_goal_ml'] as int? ?? profile.dailyBaseGoal;
        profile.dailyBaseGoal = newGoal;
        await widget.hiveService.saveProfile(profile);

        final breakdown = result['breakdown'] as Map<String, dynamic>?;
        setState(() {
          _goalMl    = newGoal;
          _baseMl    = breakdown?['base_ml']    as int?;
          _stepsMl   = breakdown?['steps_ml']   as int?;
          _workoutMl = breakdown?['workout_ml'] as int?;
          _lastAdvice = result['advice'] as String?;
          _successMsg = 'Активность отправлена на сервер ✓';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Добавление воды ───────────────────────────────────────────
  Future<void> _addWater() async {
    final profile = widget.hiveService.getProfile();
    if (profile == null) return;

    final amount = double.tryParse(_waterAmountCtrl.text) ?? 250;
    if (amount <= 0) return;

    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      // Для исторических дат — создаём запись с нужным временем
      final logDate = _isToday
          ? DateTime.now()
          : DateTime(_selectedDate.year, _selectedDate.month,
              _selectedDate.day, 12, 0); // полдень прошлого дня

      final log = _isToday
          ? await widget.hiveService.addWaterLog(amount)
          : await widget.hiveService.addWaterLogFromServer(
              amount: amount, date: logDate);

      await widget.apiService.logWater(
        firebaseUid: profile.id,
        amountMl:    amount,
        loggedAt:    logDate,
      );
      await widget.hiveService.markLogSynced(log);

      if (mounted) {
        setState(() => _successMsg = '${amount.toInt()} мл добавлено ✓');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Ошибка добавления воды: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Тест',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: const Color(0xFFF0F4F8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Выбор даты ───────────────────────────────────────
            _Card(child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 18, color: Color(0xFF1565C0)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Дата записи',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(_dateLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                )),
                if (!_isToday)
                  GestureDetector(
                    onTap: () => setState(() => _selectedDate = DateTime.now()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Сегодня',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF1565C0))),
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _pickDate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Изменить'),
                ),
              ],
            )),

            if (!_isToday) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC02)),
                ),
                child: Row(children: [
                  const Icon(Icons.history_rounded,
                      size: 14, color: Color(0xFFF57F17)),
                  const SizedBox(width: 6),
                  Text(
                    'Запись за $_dateLabel — данные уйдут в историю',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFF57F17)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 16),
            const _SectionLabel('💧 Вода'),
            _Card(child: Column(
              children: [
                _Field(
                  ctrl: _waterAmountCtrl,
                  label: 'Объём (мл)',
                  hint: '250',
                  suffix: 'мл',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [150, 200, 250, 330, 500].map((ml) => _QuickChip(
                    label: '${ml}мл',
                    onTap: () => _waterAmountCtrl.text = ml.toString(),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                _ActionButton(
                  label: 'Добавить воду',
                  icon: Icons.water_drop_rounded,
                  color: const Color(0xFF1565C0),
                  loading: _isLoading,
                  onPressed: _addWater,
                ),
              ],
            )),

            const SizedBox(height: 16),
            const _SectionLabel('🚶 Активность'),
            _Card(child: Column(
              children: [
                Row(children: [
                  Expanded(child: _Field(
                    ctrl: _stepsCtrl, label: 'Шаги', hint: '8000',
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _Field(
                    ctrl: _weightCtrl, label: 'Вес (кг)', hint: '70.0',
                    suffix: 'кг', decimal: true,
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _Field(
                    ctrl: _caloriesCtrl, label: 'Калории', hint: '450',
                    suffix: 'ккал',
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _Field(
                    ctrl: _distanceCtrl, label: 'Дистанция', hint: '6.0',
                    suffix: 'км', decimal: true,
                  )),
                ]),
                const SizedBox(height: 10),
                _Field(
                  ctrl: _heartRateCtrl, label: 'Пульс', hint: '72',
                  suffix: 'уд/мин',
                ),

                const SizedBox(height: 14),
                const _SubLabel('Тренировка'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _Field(
                    ctrl: _workoutMinsCtrl, label: 'Длительность', hint: '45',
                    suffix: 'мин',
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _DropdownField<String>(
                    label: 'Вид',
                    value: _activityName,
                    items: _activities,
                    itemLabel: (s) => s,
                    onChanged: (v) => setState(() => _activityName = v!),
                  )),
                ]),
                const SizedBox(height: 10),
                _DropdownField<WorkoutIntensity>(
                  label: 'Интенсивность',
                  value: _intensity,
                  items: WorkoutIntensity.values,
                  itemLabel: (i) => _intensityLabels[i]!,
                  onChanged: (v) => setState(() => _intensity = v!),
                ),
              ],
            )),

            const SizedBox(height: 16),
            const _SectionLabel('😴 Сон'),
            _Card(child: Column(
              children: [
                _Field(
                  ctrl: _sleepHoursCtrl, label: 'Часов сна', hint: '7.5',
                  suffix: 'ч', decimal: true,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [6.0, 7.0, 7.5, 8.0, 9.0].map((h) => _QuickChip(
                    label: '${h}ч',
                    onTap: () => _sleepHoursCtrl.text = h.toString(),
                  )).toList(),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFF7B1FA2)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'Сон влияет на нагрузку. При < 6 ч рекомендуется +200 мл к норме.',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF7B1FA2)),
                    )),
                  ]),
                ),
              ],
            )),

            const SizedBox(height: 20),
            _ActionButton(
              label: 'Отправить активность на сервер',
              icon: Icons.cloud_upload_rounded,
              color: const Color(0xFF1565C0),
              loading: _isLoading,
              onPressed: _sendActivity,
            ),

            // ── Сообщения ────────────────────────────────────────
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              _StatusBanner(message: _errorMsg!, isError: true),
            ],
            if (_successMsg != null) ...[
              const SizedBox(height: 12),
              _StatusBanner(message: _successMsg!, isError: false),
            ],

            // ── Результат с сервера ───────────────────────────────
            if (_goalMl != null) ...[
              const SizedBox(height: 16),
              const _SectionLabel('📊 Результат'),
              _Card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResultRow(
                    label: 'Норма воды на сегодня',
                    value: '$_goalMl мл',
                    valueColor: const Color(0xFF1565C0),
                    bold: true,
                  ),
                  if (_baseMl != null)
                    _ResultRow(label: '  База (вес × 30)',
                        value: '$_baseMl мл'),
                  if (_stepsMl != null)
                    _ResultRow(label: '  Бонус за шаги',
                        value: '+$_stepsMl мл'),
                  if (_workoutMl != null)
                    _ResultRow(label: '  Бонус за тренировку',
                        value: '+$_workoutMl мл'),
                  if (_lastAdvice != null) ...[
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('💡 ', style: TextStyle(fontSize: 16)),
                      Expanded(child: Text(
                        _lastAdvice!,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF424242)),
                      )),
                    ]),
                  ],
                ],
              )),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательные виджеты
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
  );
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final String? suffix;
  final bool decimal;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.suffix,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: decimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[\d.]') : RegExp(r'\d')),
    ],
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    ),
  );
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      isDense: true,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        isDense: true,
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(itemLabel(item),
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.w500)),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _StatusBanner({required this.message, required this.isError});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError
          ? const Color(0xFFFFEBEE)
          : const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isError
            ? const Color(0xFFEF9A9A)
            : const Color(0xFFA5D6A7),
      ),
    ),
    child: Row(children: [
      Icon(
        isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
        size: 16,
        color: isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: isError ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20),
        ),
      )),
    ]),
  );
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _ResultRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.black87,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: bold ? Colors.black87 : Colors.grey[700])),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor)),
      ],
    ),
  );
}

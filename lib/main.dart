import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'services/hive_service.dart';
import 'services/health_service.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  final hiveService = HiveService();
  await hiveService.init();

  final healthService = HealthService();
  final notificationService = NotificationService(
    hiveService: hiveService,
    healthService: healthService,
  );
  await notificationService.init();

  runApp(MyApp(
    hiveService: hiveService,
    healthService: healthService,
    notificationService: notificationService,
  ));
}

class MyApp extends StatelessWidget {
  final HiveService hiveService;
  final HealthService healthService;
  final NotificationService notificationService;

  const MyApp({
    super.key,
    required this.hiveService,
    required this.healthService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    final profile = hiveService.getProfile();
    final initialRoute = profile == null ? '/onboarding' : '/home';

    return MaterialApp(
      title: 'Water Reminder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/home': (context) => MyHomePage(
              hiveService: hiveService,
              healthService: healthService,
              notificationService: notificationService,
            ),
        '/onboarding': (context) => OnboardingScreen(hiveService: hiveService),
        '/history': (context) => HistoryScreen(hiveService: hiveService),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final HiveService hiveService;
  final HealthService healthService;
  final NotificationService notificationService;

  const MyHomePage({
    super.key,
    required this.hiveService,
    required this.healthService,
    required this.notificationService,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ApiService _apiService = ApiService();

  double _todayWater = 0;
  int _dailyGoal = 2000;
  bool _isSyncing = false;

  // Health данные
  int _steps = 0;
  double _weight = 0.0;
  double _calories = 0.0;
  double _distance = 0.0;
  int _heartRate = 0;

  // Данные тренировки
  int _workoutMinutes = 0;
  WorkoutIntensity _workoutIntensity = WorkoutIntensity.none;
  List<String> _activityNames = [];

  // Детализация нормы воды (от сервера)
  int _baseGoalMl = 0;
  int _stepsBonusMl = 0;
  int _workoutBonusMl = 0;
  String _serverAdvice = '';

  // Авто-синхронизация
  Timer? _autoSyncTimer;
  static const _autoSyncInterval = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _loadData();

    // Первая синхронизация при открытии приложения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncHealthData(silent: true);
    });

    // Авто-синхронизация каждые 30 минут
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      _syncHealthData(silent: true);
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final total = await widget.hiveService.getTotalWaterToday();
    final profile = widget.hiveService.getProfile();

    setState(() {
      _todayWater = total;
      if (profile != null && profile.dailyBaseGoal != null) {
        _dailyGoal = profile.dailyBaseGoal!;
      }
    });
  }

  void _addWater(double amount) async {
    await widget.hiveService.addWaterLog(amount);
    await _loadData();
    await widget.notificationService.showHydrationReminder(dailyGoal: _dailyGoal);
  }

  /// [silent] = true — без SnackBar, запускается автоматически.
  /// [silent] = false — с обратной связью, запускается кнопкой.
  Future<void> _syncHealthData({bool silent = false}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final bool granted = await widget.healthService.requestPermissions();
      if (!mounted) return;

      if (!granted) {
        if (!silent) {
          _showSnackBar('Доступ к Health Connect отклонён');
        }
        return;
      }

      // Параллельно запрашиваем все данные
      final results = await Future.wait([
        widget.healthService.getTodaySteps(),
        widget.healthService.getLatestWeight(),
        widget.healthService.getTodayCalories(),
        widget.healthService.getLatestHeartRate(),
      ]);

      final steps      = results[0] as int;
      final weight     = results[1] as double;
      final calories   = results[2] as double;
      final heartRate  = results[3] as int;
      final distance   = await widget.healthService.getTodayDistance(fallbackSteps: steps);
      final workoutSummary = await widget.healthService.getTodayWorkoutSummary(
        avgHeartRate: heartRate,
      );

      if (!mounted) return;

      setState(() {
        _steps           = steps;
        _weight          = weight;
        _calories        = calories;
        _distance        = distance;
        _heartRate       = heartRate;
        _workoutMinutes  = workoutSummary.totalMinutes;
        _workoutIntensity = workoutSummary.dominantIntensity;
        _activityNames   = workoutSummary.activityNames;
      });

      // Отправляем на сервер — используем вес из Health или из профиля
      final profile = widget.hiveService.getProfile();
      final effectiveWeight = weight > 0
          ? weight
          : (profile?.weight ?? 70.0);

      final serverResponse = await _apiService.syncActivity(
        userId: profile?.id ?? 'user_local',
        steps: steps,
        weightKg: effectiveWeight,
        workoutMinutes: workoutSummary.totalMinutes,
        workoutIntensity: workoutSummary.dominantIntensity,
        activityNames: workoutSummary.activityNames,
      );

      if (!mounted) return;

      if (serverResponse != null) {
        final newGoal = serverResponse['daily_goal_ml'] as int? ?? _dailyGoal;
        final breakdown = serverResponse['breakdown'] as Map<String, dynamic>?;
        final advice = serverResponse['advice'] as String? ?? '';

        // Сохраняем обновлённую норму в профиль
        if (profile != null) {
          profile.dailyBaseGoal = newGoal;
          profile.lastSync = DateTime.now();
          await widget.hiveService.saveProfile(profile);
        }

        setState(() {
          _dailyGoal      = newGoal;
          _baseGoalMl     = breakdown?['base_ml'] as int? ?? 0;
          _stepsBonusMl   = breakdown?['steps_ml'] as int? ?? 0;
          _workoutBonusMl = breakdown?['workout_ml'] as int? ?? 0;
          _serverAdvice   = advice;
        });

        if (!silent) {
          _showSnackBar('Норма обновлена: $_dailyGoal мл 💧');
        }
      } else {
        // Сервер недоступен — считаем локально
        _recalculateGoalLocally(
          weightKg: effectiveWeight,
          steps: steps,
          workoutMinutes: workoutSummary.totalMinutes,
          intensity: workoutSummary.dominantIntensity,
        );
        if (!silent) {
          _showSnackBar('Синхронизировано (офлайн режим)');
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Локальный расчёт нормы — зеркало формулы бэкенда
  void _recalculateGoalLocally({
    required double weightKg,
    required int steps,
    required int workoutMinutes,
    required WorkoutIntensity intensity,
  }) {
    const mlPerHour = {
      WorkoutIntensity.none:    0,
      WorkoutIntensity.low:     200,
      WorkoutIntensity.medium:  400,
      WorkoutIntensity.high:    600,
      WorkoutIntensity.extreme: 900,
    };

    final base    = (weightKg * 30).toInt();
    final steps_  = ((steps / 1000) * 50).toInt();
    final workout = ((mlPerHour[intensity] ?? 0) * workoutMinutes / 60).toInt();
    final total   = base + steps_ + workout;

    setState(() {
      _baseGoalMl     = base;
      _stepsBonusMl   = steps_;
      _workoutBonusMl = workout;
      _dailyGoal      = total;
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Reminder'),
        actions: [
          // Индикатор авто-синхронизации / кнопка ручной
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: () => _syncHealthData(silent: false),
                  tooltip: 'Синхронизировать с Health Connect',
                ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildWaterProgress(),
              const SizedBox(height: 16),
              if (_baseGoalMl > 0) _buildGoalBreakdown(),
              if (_serverAdvice.isNotEmpty) _buildAdviceBanner(),
              const SizedBox(height: 24),
              _buildWaterButtons(),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildHealthStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterProgress() {
    final progress = (_todayWater / _dailyGoal).clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 12,
            backgroundColor: Colors.blue.shade100,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${_todayWater.toInt()} / $_dailyGoal мл',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          '${(progress * 100).toInt()}% от нормы',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Детализация: из чего складывается норма
  Widget _buildGoalBreakdown() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Норма воды — $_dailyGoal мл',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _breakdownRow('💧 Базовая (вес)', '$_baseGoalMl мл'),
            _breakdownRow('🚶 Шаги ($_steps)', '+$_stepsBonusMl мл'),
            if (_workoutBonusMl > 0)
              _breakdownRow(
                '🏃 ${_activityNames.isNotEmpty ? _activityNames.join(', ') : 'Тренировка'} ($_workoutMinutes мин)',
                '+$_workoutBonusMl мл',
              ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAdviceBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_serverAdvice,
                style: const TextStyle(fontSize: 13, color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _waterButton(250, 'Стакан\n250 мл'),
        _waterButton(500, 'Бутылка\n500 мл'),
      ],
    );
  }

  Widget _buildHealthStats() {
    final intensityLabel = {
      WorkoutIntensity.none:    '—',
      WorkoutIntensity.low:     'Низкая',
      WorkoutIntensity.medium:  'Средняя',
      WorkoutIntensity.high:    'Высокая',
      WorkoutIntensity.extreme: 'Очень высокая',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Health Connect',
                style: Theme.of(context).textTheme.titleLarge),
            if (!_isSyncing)
              Text(
                'Авто: каждые 30 мин',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: [
            _statCard(Icons.directions_walk, 'Шаги', '$_steps'),
            _statCard(Icons.monitor_weight, 'Вес',
                _weight > 0 ? '${_weight.toStringAsFixed(1)} кг' : '—'),
            _statCard(Icons.local_fire_department, 'Калории',
                '${_calories.toInt()} ккал'),
            _statCard(Icons.map, 'Дистанция',
                '${(_distance / 1000).toStringAsFixed(2)} км'),
            _statCard(Icons.favorite, 'Пульс',
                _heartRate > 0 ? '$_heartRate уд/мин' : '—'),
            _statCard(Icons.fitness_center, 'Тренировка',
                _workoutMinutes > 0
                    ? '$_workoutMinutes мин\n${intensityLabel[_workoutIntensity]}'
                    : '—'),
          ],
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _waterButton(double amount, String label) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _addWater(amount),
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
          ),
          child: const Icon(Icons.local_drink),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

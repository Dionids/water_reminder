import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/hive_service.dart';
import 'services/health_service.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'services/sync_service.dart';
import 'services/wear_sync_service.dart';
import 'services/home_widget_service.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/test_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initializeDateFormatting('ru', null);

  // Firebase — инициализируем первым
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final hiveService = HiveService();
  await hiveService.init();

  final authService = AuthService(hiveService, ApiService());

  // Инициализируем WorkManager для фоновой синхронизации
  await SyncService.initWorkManager();
  await SyncService.registerBackgroundSync();

  final healthService = HealthService();
  final notificationService = NotificationService(
    hiveService: hiveService,
    healthService: healthService,
  );
  await notificationService.init();

  // Восстанавливаем Firebase сессию
  final existingProfile = await authService.initializeAuth();

  // Если Hive пустой (новое устройство), но пользователь уже авторизован —
  // подтягиваем логи воды за последние 7 дней с сервера
  if (existingProfile?.firebaseUid != null) {
    final todayTotal = await hiveService.getTotalWaterToday();
    if (todayTotal == 0) {
      try {
        final apiService = ApiService();
        int restored = 0;
        // Восстанавливаем каждый из последних 7 дней
        for (int i = 0; i < 7; i++) {
          final day = DateTime.now().subtract(Duration(days: i));
          final dateStr =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final serverLogs = await apiService.getWaterLogs(
            existingProfile!.firebaseUid!,
            date: dateStr,
          );
          final logs = serverLogs?['logs'] as List<dynamic>?;
          if (logs != null && logs.isNotEmpty) {
            for (final entry in logs) {
              final amountMl = (entry['amount_ml'] as num).toDouble();
              final loggedAt = DateTime.parse(entry['logged_at'] as String);
              await hiveService.addWaterLogFromServer(
                  amount: amountMl, date: loggedAt);
              restored++;
            }
          }
        }
        debugPrint('Восстановлено $restored логов воды с сервера (7 дней)');
      } catch (e) {
        debugPrint('Не удалось восстановить логи воды: $e');
      }
    }
  }

  runApp(MyApp(
    hiveService: hiveService,
    authService: authService,
    healthService: healthService,
    notificationService: notificationService,
    hasExistingProfile: existingProfile?.weight != null,
    apiService: ApiService(),
  ));
}

class MyApp extends StatelessWidget {
  final HiveService hiveService;
  final AuthService authService;
  final HealthService healthService;
  final NotificationService notificationService;
  final bool hasExistingProfile;
  final ApiService apiService;

  const MyApp({
    super.key,
    required this.hiveService,
    required this.authService,
    required this.healthService,
    required this.notificationService,
    required this.hasExistingProfile,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    // Маршрутизация:
    // нет профиля → /login (новый пользователь)
    // есть uid, нет веса → /onboarding (вошёл через Google, но не заполнил данные)
    // есть всё → /home
    final String initialRoute;
    final profile = hiveService.getProfile();
    if (profile?.firebaseUid == null) {
      initialRoute = '/login';
    } else if (!hasExistingProfile) {
      initialRoute = '/onboarding';
    } else {
      initialRoute = '/home';
    }

    return MaterialApp(
      title: 'AquaTrack',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: const Locale('ru'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => LoginScreen(
              authService: authService,
              hiveService: hiveService,
            ),
        '/home': (context) => MyHomePage(
              hiveService: hiveService,
              healthService: healthService,
              notificationService: notificationService,
            ),
        '/onboarding': (context) => OnboardingScreen(
              hiveService: hiveService,
              healthService: healthService,
            ),
        '/history': (context) => HistoryScreen(hiveService: hiveService),
        '/profile': (context) => ProfileScreen(
              hiveService: hiveService,
              healthService: healthService,
              authService: authService,
            ),
        '/test': (context) => TestScreen(
              hiveService: hiveService,
              apiService: apiService,
            ),
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

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  double _todayWater = 0;
  int _dailyGoal = 2000;
  bool _isSyncing = false;

  int _steps = 0;
  double _weight = 0.0;
  double _calories = 0.0;
  double _distance = 0.0;
  int _heartRate = 0;
  int _workoutMinutes = 0;
  WorkoutIntensity _workoutIntensity = WorkoutIntensity.none;
  List<String> _activityNames = [];

  int _baseGoalMl = 0;
  int _stepsBonusMl = 0;
  int _workoutBonusMl = 0;
  String _serverAdvice = '';
  DateTime? _lastSyncTime;

  SyncState get _syncState => SyncState(lastSyncTime: _lastSyncTime, isSyncing: _isSyncing);

  // Таймер для обновления метки времени синхронизации в UI
  Timer? _uiRefreshTimer;
  Timer? _autoSyncTimer;
  static const _autoSyncInterval = Duration(minutes: 30);

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  double _animatedProgress = 0;
  // ignore: cancel_subscriptions
  StreamSubscription<int>? _wearSubscription;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncHealthData(silent: true);
    });
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      _syncHealthData(silent: true);
    });
    // Обновляем метку времени каждую минуту ("5 мин назад" → "6 мин назад")
    _uiRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    // Слушаем нажатие + с Wear OS часов
    _wearSubscription = WearSyncService().watchAddWaterStream.listen((addedMl) {
      _addWater(addedMl.toDouble());
    });
  }

  @override
  void dispose() {
    _wearSubscription?.cancel();
    _autoSyncTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final total = await widget.hiveService.getTotalWaterToday();
    final profile = widget.hiveService.getProfile();
    setState(() {
      _todayWater = total;
      if (profile?.dailyBaseGoal != null) _dailyGoal = profile!.dailyBaseGoal!;
      _lastSyncTime = profile?.lastSync;
      // Показываем вес из профиля пока Health Connect не вернёт данные
      if (_weight == 0.0 && (profile?.weight ?? 0) > 0) {
        _weight = profile!.weight!;
      }
    });
    _animateProgress(total / _dailyGoal);

    // Синхронизируем виджет на домашнем экране при каждой загрузке данных
    await HomeWidgetService().update(
      currentMl: total,
      goalMl: _dailyGoal.toDouble(),
    );
  }

  void _animateProgress(double target) {
    final begin = _animatedProgress;
    final tween = Tween<double>(begin: begin, end: target.clamp(0.0, 1.0));
    _progressController.reset();
    _progressAnimation = tween.animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    )..addListener(() => setState(() => _animatedProgress = _progressAnimation.value));
    _progressController.forward();
  }

  Future<void> _addWater(double amount) async {
    // Сохраняем локально (synced=false)
    final log = await widget.hiveService.addWaterLog(amount);
    await _loadData();
    await widget.notificationService.showHydrationReminder(dailyGoal: _dailyGoal);

    // Синхронизируем на часы
    await WearSyncService().pushToWatch(
      currentMl: _todayWater.toInt(),
      goalMl: _dailyGoal.toInt(),
    );

    // Обновляем виджет на домашнем экране
    await HomeWidgetService().update(
      currentMl: _todayWater,
      goalMl: _dailyGoal.toDouble(),
    );

    final profile = widget.hiveService.getProfile();
    if (profile?.firebaseUid != null) {
      try {
        // Отправляем лог воды на сервер
        await _apiService.logWater(
          firebaseUid: profile!.firebaseUid!,
          amountMl:    amount,
          loggedAt:    log.date,
        );
        await widget.hiveService.markLogSynced(log);

        // Обновляем activity_logs за сегодня — чтобы сервер знал актуальные данные
        // даже если Health Connect не дал новых данных
        await _apiService.syncActivity(
          firebaseUid:      profile.firebaseUid!,
          steps:            _steps,
          weightKg:         _weight > 0 ? _weight : (profile.weight ?? 70.0),
          workoutMinutes:   _workoutMinutes,
          workoutIntensity: _workoutIntensity,
          activityNames:    _activityNames,
          calories:         _calories,
          distanceM:        _distance,
        );
      } catch (_) {
        debugPrint('Water log queued offline: $amount мл');
      }
    }
  }

  /// Отправляет на сервер все логи воды которые не дошли (офлайн-очередь).
  Future<void> _flushWaterLogs(String firebaseUid) async {
    final unsynced = widget.hiveService.getUnsyncedLogs();
    if (unsynced.isEmpty) return;

    debugPrint('Flush: ${unsynced.length} неотправленных логов воды');

    for (final log in unsynced) {
      try {
        await _apiService.logWater(
          firebaseUid: firebaseUid,
          amountMl:    log.amount,
          loggedAt:    log.date,
        );
        await widget.hiveService.markLogSynced(log);
      } catch (e) {
        debugPrint('Flush error для лога ${log.date}: $e');
        break; // Если сервер недоступен — прекращаем, попробуем в следующий раз
      }
    }
  }

  /// [silent] = true — авто-синхронизация (без диалога разрешений, без SnackBar).
  /// [silent] = false — ручная синхронизация кнопкой (показывает диалог и SnackBar).
  /// Тянет данные воды с часов и синхронизирует с приложением.
  /// Если на часах больше воды (добавили через плитку) — досчитываем разницу.
  Future<void> _pullWaterFromWatch() async {
    try {
      final watchMl = await WearSyncService().pullFromWatch();
      if (watchMl == null) return;

      final phoneMl = _todayWater.toInt();
      if (watchMl > phoneMl) {
        // На часах больше — добавляем разницу в приложение
        final diff = (watchMl - phoneMl).toDouble();
        final log = await widget.hiveService.addWaterLog(diff);

        final profile = widget.hiveService.getProfile();
        if (profile?.firebaseUid != null) {
          try {
            await _apiService.logWater(
              firebaseUid: profile!.firebaseUid!,
              amountMl:    diff,
              loggedAt:    log.date,
            );
            await widget.hiveService.markLogSynced(log);
          } catch (_) {}
        }
        await _loadData();
        debugPrint('Pulled from watch: +$diff мл (watch=$watchMl, phone=$phoneMl)');
      } else if (watchMl < phoneMl) {
        // На телефоне больше — отправляем на часы
        await WearSyncService().pushToWatch(
          currentMl: phoneMl,
          goalMl:    _dailyGoal.toInt(),
        );
      }
    } catch (e) {
      debugPrint('_pullWaterFromWatch error: $e');
    }
  }

  Future<void> _syncHealthData({bool silent = false}) async {
    // Дедупликация: не синхронизируем если прошло меньше 5 минут
    // (исключение — ручной запуск всегда разрешён)
    if (silent && !_syncState.canSync) {
      debugPrint('Sync пропущен: слишком рано (последняя: ${_syncState.label})');
      return;
    }
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      // Сначала тянем данные с часов — вдруг там добавили воду через плитку
      await _pullWaterFromWatch();

      // Авто-sync: только проверяем статус без диалога.
      // Ручной sync: запрашиваем разрешения если нужно.
      final bool granted = silent
          ? await widget.healthService.checkPermissions()
          : await widget.healthService.requestPermissions();

      if (!mounted) return;
      if (!granted) {
        if (!silent) _showSnackBar('Доступ к Health Connect отклонён');
        return;
      }

      // Все данные — одним вызовом (параллельно внутри)
      final data = await widget.healthService.fetchAllTodayData();
      if (!mounted) return;

      final steps           = data['steps']            as int;
      final weight          = data['weight']           as double;
      final calories        = data['calories']         as double;
      final heartRate       = data['heartRate']        as int;
      final distance        = data['distance']         as double;
      final workoutMinutes  = data['workoutMinutes']   as int;
      final workoutIntensity = data['workoutIntensity'] as WorkoutIntensity;
      final activityNames   = data['activityNames']    as List<String>;

      final profile2 = widget.hiveService.getProfile();
      setState(() {
        _steps = steps;
        // Если Health Connect не вернул вес — используем сохранённый в профиле
        _weight = weight > 0 ? weight : (profile2?.weight ?? 0.0);
        _calories = calories;
        _distance = distance;
        _heartRate = heartRate;
        _workoutMinutes = workoutMinutes;
        _workoutIntensity = workoutIntensity;
        _activityNames = activityNames;
      });

      final profile = widget.hiveService.getProfile();
      final effectiveWeight = weight > 0 ? weight : (profile?.weight ?? 70.0);

      final serverResponse = await _apiService.syncActivity(
        firebaseUid: profile?.id ?? 'user_local',
        steps: steps,
        weightKg: effectiveWeight,
        workoutMinutes: workoutMinutes,
        workoutIntensity: workoutIntensity,
        activityNames: activityNames,
        calories: calories,
        distanceM: distance,
      );

      if (!mounted) return;

      if (serverResponse != null) {
        final newGoal   = serverResponse['daily_goal_ml'] as int? ?? _dailyGoal;
        final breakdown = serverResponse['breakdown'] as Map<String, dynamic>?;
        if (profile != null) {
          profile.dailyBaseGoal = newGoal;
          profile.lastSync = DateTime.now();
          await widget.hiveService.saveProfile(profile);
        }
        setState(() {
          _dailyGoal      = newGoal;
          _baseGoalMl     = breakdown?['base_ml']    as int? ?? 0;
          _stepsBonusMl   = breakdown?['steps_ml']   as int? ?? 0;
          _workoutBonusMl = breakdown?['workout_ml'] as int? ?? 0;
          _serverAdvice   = serverResponse['advice'] as String? ?? '';
          _lastSyncTime   = DateTime.now();
        });
        _animateProgress(_todayWater / newGoal);

        // Флаш офлайн-очереди — отправляем логи воды которые не дошли до сервера
        if (profile?.firebaseUid != null) {
          _flushWaterLogs(profile!.firebaseUid!);
        }

        // Планируем уведомления на основе данных сна
        _scheduleWaterReminders(newGoal);

        if (!silent) _showSnackBar('Норма обновлена: $newGoal мл 💧');
      } else {
        // Офлайн — считаем локально, но время синхронизации всё равно обновляем
        _recalculateGoalLocally(
          weightKg: effectiveWeight, steps: steps,
          workoutMinutes: workoutMinutes, intensity: workoutIntensity,
        );
        setState(() => _lastSyncTime = DateTime.now());
        if (profile != null) {
          profile.lastSync = DateTime.now();
          await widget.hiveService.saveProfile(profile);
        }
        // Планируем уведомления и в офлайн-режиме
        _scheduleWaterReminders(_dailyGoal);
        if (!silent) _showSnackBar('Синхронизировано (офлайн)');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Планирует уведомления о воде с фиксированным окном бодрствования.
  Future<void> _scheduleWaterReminders(int goalMl) async {
    try {
      final now   = DateTime.now();
      final wake  = DateTime(now.year, now.month, now.day, 7, 0);
      final bed   = DateTime(now.year, now.month, now.day, 23, 0);
      await widget.notificationService.scheduleDailyWaterReminders(
        wakeTime: wake,
        bedTime:  bed,
        goalMl:   goalMl,
      );
    } catch (e) {
      debugPrint('_scheduleWaterReminders error: $e');
    }
  }

  void _recalculateGoalLocally({
    required double weightKg, required int steps,
    required int workoutMinutes, required WorkoutIntensity intensity,
  }) {
    const mlPerHour = {
      WorkoutIntensity.none: 0, WorkoutIntensity.low: 200,
      WorkoutIntensity.medium: 400, WorkoutIntensity.high: 600,
      WorkoutIntensity.extreme: 900,
    };
    final base    = (weightKg * 30).toInt();
    final stepsB  = ((steps / 1000) * 50).toInt();
    final workout = ((mlPerHour[intensity] ?? 0) * workoutMinutes / 60).toInt();
    setState(() {
      _baseGoalMl = base; _stepsBonusMl = stepsB;
      _workoutBonusMl = workout; _dailyGoal = base + stepsB + workout;
    });
    _animateProgress(_todayWater / _dailyGoal);
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // _syncLabel теперь делегируется SyncState.label

  @override
  Widget build(BuildContext context) {
    final pct = _dailyGoal > 0
        ? (_todayWater / _dailyGoal * 100).clamp(0, 100).toInt()
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            backgroundColor: const Color(0xFFF0F4F8),
            elevation: 0,
            title: const Text(
              'AquaTrack',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              overflow: TextOverflow.visible,
            ),
            titleSpacing: 8,
            actions: [
              // Индикатор свежести данных
              _SyncStatusChip(syncState: _syncState),
              if (_isSyncing)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.sync_rounded),
                  onPressed: () => _syncHealthData(silent: false),
                  tooltip: 'Синхронизировать',
                ),
              IconButton(
                icon: const Icon(Icons.science_outlined),
                tooltip: 'Тест',
                onPressed: () async {
                  await Navigator.pushNamed(context, '/test');
                  _loadData();
                },
              ),
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () async {
                  await Navigator.pushNamed(context, '/profile');
                  _loadData();
                },
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded),
                onPressed: () => Navigator.pushNamed(context, '/history'),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // ── Hero Card — прогресс воды ─────────────────
                _HeroWaterCard(
                  progress: _animatedProgress,
                  todayWater: _todayWater,
                  dailyGoal: _dailyGoal,
                  pct: pct,
                  syncState: _syncState,
                  onAdd: _addWater,
                ),

                const SizedBox(height: 14),

                // ── Разбивка нормы ────────────────────────────
                if (_baseGoalMl > 0)
                  _GoalBreakdownCard(
                    base: _baseGoalMl,
                    steps: _stepsBonusMl,
                    stepsCount: _steps,
                    workout: _workoutBonusMl,
                    workoutMinutes: _workoutMinutes,
                    activityNames: _activityNames,
                    advice: _serverAdvice,
                  ),

                const SizedBox(height: 14),

                // ── Health статистика ─────────────────────────
                _HealthStatsGrid(
                  steps: _steps,
                  weight: _weight,
                  calories: _calories,
                  distance: _distance,
                  heartRate: _heartRate,
                  workoutMinutes: _workoutMinutes,
                  workoutIntensity: _workoutIntensity,
                  activityNames: _activityNames,
                ),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Card
// ─────────────────────────────────────────────────────────────────────────────

class _HeroWaterCard extends StatelessWidget {
  final double progress;
  final double todayWater;
  final int dailyGoal;
  final int pct;
  final SyncState syncState;
  final Future<void> Function(double) onAdd;

  const _HeroWaterCard({
    required this.progress, required this.todayWater,
    required this.dailyGoal, required this.pct,
    required this.syncState, required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final Color fillColor = pct >= 80
        ? const Color(0xFF1E88E5)
        : pct >= 50
            ? const Color(0xFF42A5F5)
            : const Color(0xFF90CAF9);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1565C0), fillColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: fillColor.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 340;
        return Padding(
        padding: EdgeInsets.all(isSmall ? 16 : 24),
        child: Column(
          children: [
            // Прогресс-бар волна
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${todayWater.toInt()} мл',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 30 : 40,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'из $dailyGoal мл',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: isSmall ? 13 : 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$pct% выполнено',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Большой круговой индикатор
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Кнопки добавления воды
            Row(
              children: [
                Expanded(child: _AddWaterButton(amount: 150, label: '150 мл', onAdd: onAdd)),
                const SizedBox(width: 10),
                Expanded(child: _AddWaterButton(amount: 250, label: 'Стакан\n250 мл', onAdd: onAdd, primary: true)),
                const SizedBox(width: 10),
                Expanded(child: _AddWaterButton(amount: 500, label: 'Бутылка\n500 мл', onAdd: onAdd)),
              ],
            ),

            const SizedBox(height: 12),
            _SyncFooter(syncState: syncState),
          ],
        ),
        );
      }),
    );
  }
}

class _AddWaterButton extends StatelessWidget {
  final double amount;
  final String label;
  final Future<void> Function(double) onAdd;
  final bool primary;

  const _AddWaterButton({
    required this.amount, required this.label,
    required this.onAdd, this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onAdd(amount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: primary ? 14 : 10),
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.water_drop_rounded,
              color: primary ? const Color(0xFF1565C0) : Colors.white,
              size: primary ? 22 : 18,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primary ? const Color(0xFF1565C0) : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goal Breakdown Card
// ─────────────────────────────────────────────────────────────────────────────

class _GoalBreakdownCard extends StatelessWidget {
  final int base, steps, stepsCount, workout, workoutMinutes;
  final List<String> activityNames;
  final String advice;

  const _GoalBreakdownCard({
    required this.base, required this.steps, required this.stepsCount,
    required this.workout, required this.workoutMinutes,
    required this.activityNames, required this.advice,
  });

  @override
  Widget build(BuildContext context) {
    final total = base + steps + workout;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_rounded, color: Color(0xFF1565C0), size: 20),
              const SizedBox(width: 8),
              Text('Норма воды: $total мл',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          _BreakdownRow(icon: '💧', label: 'Базовая (вес)', value: base, total: total, color: const Color(0xFF1565C0)),
          const SizedBox(height: 8),
          _BreakdownRow(icon: '🚶', label: 'Шаги ($stepsCount)', value: steps, total: total, color: const Color(0xFF43A047)),
          if (workout > 0) ...[
            const SizedBox(height: 8),
            _BreakdownRow(
              icon: '🏃',
              label: activityNames.isNotEmpty ? activityNames.join(', ') : 'Тренировка $workoutMinutes мин',
              value: workout, total: total, color: const Color(0xFFE53935),
            ),
          ],
          if (advice.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(advice, style: const TextStyle(fontSize: 13, color: Color(0xFF1565C0)))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String icon, label;
  final int value, total;
  final Color color;

  const _BreakdownRow({required this.icon, required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final frac = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$icon $label', style: const TextStyle(fontSize: 13)),
            Text('$value мл', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac, minHeight: 5,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Health Stats Grid
// ─────────────────────────────────────────────────────────────────────────────

class _HealthStatsGrid extends StatelessWidget {
  final int steps, heartRate, workoutMinutes;
  final double weight, calories, distance;
  final WorkoutIntensity workoutIntensity;
  final List<String> activityNames;

  const _HealthStatsGrid({
    required this.steps, required this.weight, required this.calories,
    required this.distance, required this.heartRate,
    required this.workoutMinutes, required this.workoutIntensity,
    required this.activityNames,
  });

  @override
  Widget build(BuildContext context) {
    final intensityLabel = {
      WorkoutIntensity.none: '—', WorkoutIntensity.low: 'Низкая',
      WorkoutIntensity.medium: 'Средняя', WorkoutIntensity.high: 'Высокая',
      WorkoutIntensity.extreme: 'Очень высокая',
    };

    final workoutValue = workoutMinutes > 0
        ? '$workoutMinutes мин · ${intensityLabel[workoutIntensity]}'
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Health Connect',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 12) / 2;
            final aspectRatio = (tileWidth / 80).clamp(1.5, 2.2);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: aspectRatio,
              children: [
            _StatTile(icon: Icons.directions_walk_rounded, label: 'Шаги', value: '$steps', color: const Color(0xFF43A047)),
            _StatTile(icon: Icons.monitor_weight_rounded, label: 'Вес',
                value: weight > 0 ? '${weight.toStringAsFixed(1)} кг' : '—', color: const Color(0xFF8E24AA)),
            _StatTile(icon: Icons.local_fire_department_rounded, label: 'Калории',
                value: '${calories.toInt()} ккал', color: const Color(0xFFE53935)),
            _StatTile(icon: Icons.map_rounded, label: 'Дистанция',
                value: '${(distance / 1000).toStringAsFixed(2)} км', color: const Color(0xFF00897B)),
            _StatTile(icon: Icons.favorite_rounded, label: 'Пульс',
                value: heartRate > 0 ? '$heartRate уд/мин' : '—', color: const Color(0xFFE91E63)),
            _StatTile(icon: Icons.fitness_center_rounded, label: 'Тренировка',
                value: workoutValue, color: const Color(0xFFFF6F00)),
          ],
            );
          },
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis),
              Text(value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Индикатор свежести в AppBar — цветная точка + метка
// ─────────────────────────────────────────────────────────────────────────────

class _SyncStatusChip extends StatelessWidget {
  final SyncState syncState;
  const _SyncStatusChip({required this.syncState});

  @override
  Widget build(BuildContext context) {
    if (syncState.isSyncing) return const SizedBox.shrink();

    final Color dotColor;
    final String tooltip;

    switch (syncState.freshness) {
      case SyncFreshness.fresh:
        dotColor = const Color(0xFF43A047); // зелёный
        tooltip = 'Данные актуальны: ${syncState.label}';
      case SyncFreshness.aging:
        dotColor = const Color(0xFFFFA000); // жёлтый
        tooltip = 'Данные устаревают: ${syncState.label}';
      case SyncFreshness.stale:
        dotColor = const Color(0xFFE53935); // красный
        tooltip = 'Данные устарели: ${syncState.label}';
      case SyncFreshness.unknown:
        dotColor = Colors.grey;
        tooltip = 'Не синхронизировано';
    }

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              syncState.label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Нижняя строка Hero карточки — с предупреждением если данные устарели
// ─────────────────────────────────────────────────────────────────────────────

class _SyncFooter extends StatelessWidget {
  final SyncState syncState;
  const _SyncFooter({required this.syncState});

  @override
  Widget build(BuildContext context) {
    final isStale = syncState.isStale;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isStale
          ? Container(
              key: const ValueKey('stale'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white.withOpacity(0.9),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Данные устарели',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            )
          : Text(
              syncState.label,
              key: const ValueKey('fresh'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
    );
  }
}

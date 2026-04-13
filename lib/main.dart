import 'package:flutter/material.dart';
import 'services/isar_service.dart';
import 'services/health_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/history_screen.dart';
import 'widgets/water_wave_painter.dart';
import 'models/user_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final isarService = await IsarService.build();
  final healthService = HealthService();
  final apiService = ApiService();
  final notificationService = NotificationService(
    isarService: isarService,
    healthService: healthService,
  );
  
  await notificationService.init();
  
  runApp(MyApp(
    isarService: isarService,
    healthService: healthService,
    apiService: apiService,
    notificationService: notificationService,
  ));
}

class MyApp extends StatelessWidget {
  final IsarService isarService;
  final HealthService healthService;
  final ApiService apiService;
  final NotificationService notificationService;
  
  const MyApp({
    super.key, 
    required this.isarService,
    required this.healthService,
    required this.apiService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Reminder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Initializer(
        isarService: isarService,
        healthService: healthService,
        apiService: apiService,
        notificationService: notificationService,
      ),
    );
  }
}

class Initializer extends StatefulWidget {
  final IsarService isarService;
  final HealthService healthService;
  final ApiService apiService;
  final NotificationService notificationService;

  const Initializer({
    super.key,
    required this.isarService,
    required this.healthService,
    required this.apiService,
    required this.notificationService,
  });

  @override
  State<Initializer> createState() => _InitializerState();
}

class _InitializerState extends State<Initializer> {
  bool? _isProfileComplete;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final profile = await widget.isarService.getProfile();
    if (mounted) {
      setState(() {
        _isProfileComplete = profile != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProfileComplete == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isProfileComplete!) {
      return OnboardingScreen(
        isarService: widget.isarService,
        onComplete: () => setState(() => _isProfileComplete = true),
      );
    }

    return MainContainer(
      isarService: widget.isarService,
      healthService: widget.healthService,
      apiService: widget.apiService,
      notificationService: widget.notificationService,
    );
  }
}

class MainContainer extends StatefulWidget {
  final IsarService isarService;
  final HealthService healthService;
  final ApiService apiService;
  final NotificationService notificationService;

  const MainContainer({
    super.key,
    required this.isarService,
    required this.healthService,
    required this.apiService,
    required this.notificationService,
  });

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      MyHomePage(
        title: 'Water Reminder',
        isarService: widget.isarService,
        healthService: widget.healthService,
        apiService: widget.apiService,
        notificationService: widget.notificationService,
      ),
      HistoryScreen(isarService: widget.isarService),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key, 
    required this.title, 
    required this.isarService,
    required this.healthService,
    required this.apiService,
    required this.notificationService,
  });

  final String title;
  final IsarService isarService;
  final HealthService healthService;
  final ApiService apiService;
  final NotificationService notificationService;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _totalWater = 0;
  int _steps = 0;
  int _dailyGoal = 2000;
  String _advice = "Stay hydrated!";
  bool _isAuthorized = false;
  bool _isSyncing = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final authorized = await widget.healthService.requestPermissions();
    await widget.notificationService.requestPermissions();
    
    _profile = await widget.isarService.getProfile();
    
    if (!mounted) return;
    setState(() {
      _isAuthorized = authorized;
      if (_profile != null && _profile!.dailyBaseGoal != null) {
        _dailyGoal = _profile!.dailyBaseGoal!;
      }
    });

    await _loadWaterData();
    if (authorized) {
      await _syncWithBackend();
    }
  }

  Future<void> _loadWaterData() async {
    final total = await widget.isarService.getTodayTotalWater();
    if (!mounted) return;
    setState(() => _totalWater = total);
  }

  Future<void> _syncWithBackend() async {
    if (!_isAuthorized) return;
    setState(() => _isSyncing = true);

    try {
      final steps = await widget.healthService.getTodaySteps();
      final result = await widget.apiService.syncActivity(
        userId: "user_123",
        steps: steps,
        workoutMinutes: 0,
        weight: _profile?.weight ?? 70.0,
      );

      if (result != null && mounted) {
        setState(() {
          _steps = steps;
          _dailyGoal = result['daily_goal_ml'] as int;
          _advice = result['advice'] as String;
        });
        await widget.isarService.updateActivityCache(steps, 0, false);
      }
    } catch (e) {
      // Ignore sync errors
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _addWater() async {
    await widget.isarService.addWater(250);
    await _loadWaterData();
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_totalWater / _dailyGoal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: _isSyncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_sync),
            onPressed: _isSyncing ? null : _syncWithBackend,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncWithBackend,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_advice, style: const TextStyle(fontStyle: FontStyle.italic))),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
        
                Stack(
                  alignment: Alignment.center,
                  children: [
                    WaterWaveProgress(progress: progress, size: 220),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_totalWater', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                        Text('of $_dailyGoal ml', style: const TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 40),
        
                Card(
                  elevation: 0,
                  color: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.directions_walk, color: Colors.orange, size: 32),
                    title: Text('$_steps steps', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Activity data from sensors'),
                    trailing: Text('+${((_steps / 1000).floor() * 100)} ml', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                
                OutlinedButton.icon(
                  onPressed: () => widget.notificationService.showHydrationReminder(dailyGoal: _dailyGoal),
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Test Smart Notification'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWater,
        label: const Text('Add 250ml', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.local_drink),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }
}

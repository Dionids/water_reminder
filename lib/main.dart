import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'services/hive_service.dart';
import 'services/health_service.dart';
import 'services/notification_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  
  // Initialize Services
  final hiveService = HiveService();
  await hiveService.init();
  
  final healthService = HealthService();
  final notificationService = NotificationService(
    hiveService: hiveService, 
    healthService: healthService
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
    // Check if profile exists to decide initial route
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
  double _todayWater = 0;
  int _dailyGoal = 2000;

  @override
  void initState() {
    super.initState();
    _loadData();
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
    
    // Test notification logic after adding water
    await widget.notificationService.showHydrationReminder(dailyGoal: _dailyGoal);
  }

  Future<void> _checkHealthConnection() async {
    final bool granted = await widget.healthService.requestPermissions();
    if (granted) {
      final steps = await widget.healthService.getTodaySteps();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Доступ разрешен! Шагов за сегодня: $steps")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Доступ к Health Connect отклонен")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Water Reminder"),
        actions: [
          IconButton(
            icon: const Icon(Icons.health_and_safety),
            onPressed: _checkHealthConnection,
            tooltip: "Проверить Samsung Health",
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: (_todayWater / _dailyGoal).clamp(0.0, 1.0),
              strokeWidth: 10,
              backgroundColor: Colors.blue.shade100,
            ),
            const SizedBox(height: 30),
            Text(
              "${_todayWater.toInt()} / $_dailyGoal ml",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _waterButton(250, "Glass"),
                _waterButton(500, "Bottle"),
              ],
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
        Text(label),
      ],
    );
  }
}

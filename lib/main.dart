import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'services/hive_service.dart';
import 'services/health_service.dart';
import 'services/notification_service.dart';
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
  
  // Новые данные из Health Connect
  int _steps = 0;
  double _weight = 0.0;
  double _calories = 0.0;
  double _distance = 0.0;
  int _heartRate = 0;

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
    await widget.notificationService.showHydrationReminder(dailyGoal: _dailyGoal);
  }

  Future<void> _syncHealthData() async {
    final bool granted = await widget.healthService.requestPermissions();
    if (!mounted) return;

    if (granted) {
      final steps = await widget.healthService.getTodaySteps();
      final weight = await widget.healthService.getLatestWeight();
      final calories = await widget.healthService.getTodayCalories();
      final distance = await widget.healthService.getTodayDistance();
      final heartRate = await widget.healthService.getLatestHeartRate();

      if (!mounted) return;

      setState(() {
        _steps = steps;
        _weight = weight;
        _calories = calories;
        _distance = distance;
        _heartRate = heartRate;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Данные Samsung Health синхронизированы!")),
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
            icon: const Icon(Icons.sync),
            onPressed: _syncHealthData,
            tooltip: "Синхронизировать с Samsung Health",
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
              const SizedBox(height: 40),
              _buildWaterButtons(),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),
              _buildHealthStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterProgress() {
    return Column(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CircularProgressIndicator(
            value: (_todayWater / _dailyGoal).clamp(0.0, 1.0),
            strokeWidth: 12,
            backgroundColor: Colors.blue.shade100,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "${_todayWater.toInt()} / $_dailyGoal ml",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }

  Widget _buildWaterButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _waterButton(250, "Glass"),
        _waterButton(500, "Bottle"),
      ],
    );
  }

  Widget _buildHealthStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Samsung Health Stats",
          style: Theme.of(context).textTheme.titleLarge,
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
            _statCard(Icons.directions_walk, "Steps", "$_steps"),
            _statCard(Icons.monitor_weight, "Weight", "${_weight.toStringAsFixed(1)} kg"),
            _statCard(Icons.local_fire_department, "Calories", "${_calories.toInt()} kcal"),
            _statCard(Icons.map, "Distance", "${(_distance / 1000).toStringAsFixed(2)} km"),
            _statCard(Icons.favorite, "Heart Rate", "$_heartRate bpm"),
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
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
        Text(label),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'services/isar_service.dart';
import 'services/health_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';

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
      home: MyHomePage(
        title: 'Water Reminder', 
        isarService: isarService,
        healthService: healthService,
        apiService: apiService,
        notificationService: notificationService,
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

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final authorized = await widget.healthService.requestPermissions();
    await widget.notificationService.requestPermissions();
    
    if (!mounted) return;
    setState(() => _isAuthorized = authorized);

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
      );

      if (result != null && mounted) {
        setState(() {
          _steps = steps;
          _dailyGoal = result['daily_goal_ml'];
          _advice = result['advice'];
        });
        await widget.isarService.updateActivityCache(steps, 0, false);
      }
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
          if (_isSyncing)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
            IconButton(
              icon: const Icon(Icons.cloud_sync),
              onPressed: _syncWithBackend,
            )
        ],
      ),
      body: SingleChildScrollView(
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
                  SizedBox(
                    width: 200, height: 200,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.blue.shade100,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_totalWater', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                      Text('of $_dailyGoal ml', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 40),

              Card(
                elevation: 0,
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.directions_walk, color: Colors.orange),
                  title: Text('$_steps steps'),
                  subtitle: const Text('Data synced from your device'),
                ),
              ),
              const SizedBox(height: 20),
              
              // New: Test Smart Notification Button
              OutlinedButton.icon(
                onPressed: () => widget.notificationService.showHydrationReminder(dailyGoal: _dailyGoal),
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test Smart Notification'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWater,
        label: const Text('Add 250ml'),
        icon: const Icon(Icons.local_drink),
      ),
    );
  }
}

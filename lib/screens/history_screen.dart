import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/isar_service.dart';
import '../models/water_log.dart';

class HistoryScreen extends StatefulWidget {
  final IsarService isarService;

  const HistoryScreen({super.key, required this.isarService});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<BarChartGroupData> _chartGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final now = DateTime.now();
    List<BarChartGroupData> groups = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final total = await widget.isarService.getWaterForDay(date);
      
      groups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: total.toDouble(),
              color: Colors.blue.shade400,
              width: 18,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 3000,
                color: Colors.blue.shade50,
              ),
            ),
          ],
        ),
      );
    }

    setState(() {
      _chartGroups = groups;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly History')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Progress',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text('Water intake for the last 7 days (ml)'),
                const SizedBox(height: 40),
                
                AspectRatio(
                  aspectRatio: 1.5,
                  child: BarChart(
                    BarChartData(
                      barGroups: _chartGroups,
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              final index = value.toInt() % 7;
                              return Text(days[index], style: const TextStyle(color: Colors.grey));
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.insights, color: Colors.blue),
                    title: Text('Health Insight'),
                    subtitle: Text('Consistency is key! Try to reach your goal 5 days in a row.'),
                  ),
                )
              ],
            ),
          ),
    );
  }
}

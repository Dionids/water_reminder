import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/hive_service.dart';
import '../models/water_log.dart';

class HistoryScreen extends StatefulWidget {
  final HiveService hiveService;
  const HistoryScreen({super.key, required this.hiveService});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<WaterLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await widget.hiveService.getAllLogs();
    setState(() {
      _logs = logs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return ListTile(
            title: Text("${log.amount.toInt()} ml"),
            subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(log.date)),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                // Используем HiveObject.delete() для удаления конкретной записи,
                // чтобы избежать удаления не того лога из-за сортировки.
                await log.delete();
                _loadLogs();
              },
            ),
          );
        },
      ),
    );
  }
}

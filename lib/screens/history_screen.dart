import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/hive_service.dart';
import '../services/api_service.dart';
import '../models/water_log.dart';

class HistoryScreen extends StatefulWidget {
  final HiveService hiveService;
  const HistoryScreen({super.key, required this.hiveService});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<WaterLog> _logs = [];
  Map<String, double> _dailyTotals = {};
  List<Map<String, dynamic>> _serverDays = []; // данные по дням с сервера
  final ApiService _apiService = ApiService();

  // Аналитика с сервера
  int? _avgCompletion;
  int? _avgSteps;
  String? _bestDay;
  String? _worstDay;
  bool _analyticsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadAnalytics();
  }

  Future<void> _loadLogs() async {
    final logs = await widget.hiveService.getAllLogs();
    final Map<String, double> totals = {};
    for (final log in logs) {
      final key = DateFormat('yyyy-MM-dd').format(log.date);
      totals[key] = (totals[key] ?? 0) + log.amount;
    }
    setState(() {
      _logs = logs;
      _dailyTotals = totals;
    });
  }

  Future<void> _loadAnalytics() async {
    final profile = widget.hiveService.getProfile();
    final uid = profile?.firebaseUid;
    if (uid == null) return;

    setState(() => _analyticsLoading = true);
    try {
      final data = await _apiService.getAnalytics(uid, days: 7);
      if (data != null && mounted) {
        final days = (data['days'] as List<dynamic>? ?? [])
            .map((d) => d as Map<String, dynamic>)
            .toList();

        // Строим _dailyTotals из серверных данных (дополняет локальные логи)
        final serverTotals = <String, double>{};
        for (final d in days) {
          final dateKey = d['date'] as String?;
          final consumed = (d['consumed_ml'] as num?)?.toDouble() ?? 0;
          if (dateKey != null && consumed > 0) {
            serverTotals[dateKey] = consumed;
          }
        }

        setState(() {
          _avgCompletion = data['avg_completion'] as int?;
          _avgSteps      = data['avg_steps'] as int?;
          _bestDay       = data['best_day'] as String?;
          _worstDay      = data['worst_day'] as String?;
          _serverDays    = days;
          // Мержим: локальные данные приоритетнее (они точнее),
          // серверные заполняют пробелы
          for (final entry in serverTotals.entries) {
            if (!_dailyTotals.containsKey(entry.key) ||
                _dailyTotals[entry.key] == 0) {
              _dailyTotals[entry.key] = entry.value;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('HistoryScreen: не удалось загрузить аналитику: $e');
    } finally {
      if (mounted) setState(() => _analyticsLoading = false);
    }
  }

  /// Последние 7 дней для графика
  List<MapEntry<String, double>> get _last7Days {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      return MapEntry(key, _dailyTotals[key] ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4F8),
        elevation: 0,
        title: const Text('История', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Карточки аналитики с сервера ──────────────
                if (_analyticsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_avgCompletion != null)
                  _AnalyticsCard(
                    avgCompletion: _avgCompletion!,
                    avgSteps: _avgSteps ?? 0,
                    bestDay: _bestDay,
                    worstDay: _worstDay,
                  ),

                if (_avgCompletion != null) const SizedBox(height: 14),

                // ── График 7 дней ─────────────────────────────
                _WeekChart(last7Days: _last7Days),
                const SizedBox(height: 16),

                // ── Лог записей ───────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                        child: Text('Все записи',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (_logs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Нет записей', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _logs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 20),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.water_drop_rounded,
                                    color: Color(0xFF1565C0), size: 20),
                              ),
                              title: Text(
                                '${log.amount.toInt()} мл',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                DateFormat('d MMM, HH:mm', 'ru').format(log.date),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () async {
                                  await log.delete();
                                  _loadLogs();
                                },
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
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
// График 7 дней
// ─────────────────────────────────────────────────────────────────────────────

class _WeekChart extends StatelessWidget {
  final List<MapEntry<String, double>> last7Days;
  const _WeekChart({required this.last7Days});

  @override
  Widget build(BuildContext context) {
    final maxVal = last7Days.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = maxVal > 0 ? maxVal * 1.3 : 3000.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Последние 7 дней',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'мл воды в день',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: chartMax,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()} мл',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= last7Days.length) return const SizedBox();
                        final date = DateTime.parse(last7Days[idx].key);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('E', 'ru').format(date),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade100, strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(last7Days.length, (i) {
                  final val = last7Days[i].value;
                  final isToday = i == last7Days.length - 1;
                  final color = val >= 2000
                      ? const Color(0xFF1E88E5)
                      : val >= 1000
                          ? const Color(0xFF90CAF9)
                          : Colors.grey.shade300;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: isToday ? const Color(0xFF1565C0) : color,
                        width: 28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: chartMax,
                          color: Colors.grey.shade50,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: const Color(0xFF1E88E5), label: '≥ 2000 мл'),
              const SizedBox(width: 16),
              _Legend(color: const Color(0xFF90CAF9), label: '1000–2000'),
              const SizedBox(width: 16),
              _Legend(color: Colors.grey.shade300, label: '< 1000'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Карточка аналитики с сервера
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsCard extends StatelessWidget {
  final int avgCompletion;
  final int avgSteps;
  final String? bestDay;
  final String? worstDay;

  const _AnalyticsCard({
    required this.avgCompletion,
    required this.avgSteps,
    this.bestDay,
    this.worstDay,
  });

  String _formatDay(String? isoDate) {
    if (isoDate == null) return '—';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('d MMM', 'ru').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  Color get _completionColor {
    if (avgCompletion >= 80) return const Color(0xFF1E88E5);
    if (avgCompletion >= 50) return const Color(0xFFFFA000);
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: Color(0xFF1565C0), size: 18),
              SizedBox(width: 8),
              Text('Статистика за 7 дней',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.water_drop_rounded,
                  label: 'Норма выполнена',
                  value: '$avgCompletion%',
                  color: _completionColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.directions_walk_rounded,
                  label: 'Среднее шагов',
                  value: avgSteps > 0 ? avgSteps.toString() : '—',
                  color: const Color(0xFF43A047),
                ),
              ),
            ],
          ),
          if (bestDay != null || worstDay != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (bestDay != null)
                  Expanded(
                    child: _StatCard(
                      icon: Icons.emoji_events_rounded,
                      label: 'Лучший день',
                      value: _formatDay(bestDay),
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                if (bestDay != null && worstDay != null) const SizedBox(width: 10),
                if (worstDay != null)
                  Expanded(
                    child: _StatCard(
                      icon: Icons.trending_down_rounded,
                      label: 'Худший день',
                      value: _formatDay(worstDay),
                      color: const Color(0xFFE53935),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              )),
        ],
      ),
    );
  }
}

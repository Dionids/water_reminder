import 'package:hive/hive.dart';

part 'water_log.g.dart';

@HiveType(typeId: 0)
class WaterLog extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime date;

  /// Флаг — отправлен ли лог на сервер.
  /// false = нужно отправить при следующей синхронизации (офлайн-очередь).
  @HiveField(3)
  bool synced;

  WaterLog({
    this.id,
    required this.amount,
    required this.date,
    this.synced = false,
  });
}

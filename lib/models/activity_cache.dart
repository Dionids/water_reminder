import 'package:hive/hive.dart';

part 'activity_cache.g.dart';

@HiveType(typeId: 2)
class ActivityCache extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final bool isAsleep;

  @HiveField(2)
  final int stepCount;

  @HiveField(3)
  final int lastSyncTimestamp;

  ActivityCache({
    required this.date,
    required this.isAsleep,
    required this.stepCount,
    required this.lastSyncTimestamp,
  });
}

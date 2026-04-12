import 'package:isar/isar.dart';

part 'activity_cache.g.dart';

@collection
class ActivityCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  DateTime date; // Day for which we cache activity

  int steps;
  int workoutMinutes;
  bool isAsleep; // Status from health data

  ActivityCache({
    required this.date,
    this.steps = 0,
    this.workoutMinutes = 0,
    this.isAsleep = false,
  });
}

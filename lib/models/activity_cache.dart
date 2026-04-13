import 'package:isar/isar.dart';

part 'activity_cache.g.dart';

@collection
class ActivityCache {
  Id id = Isar.autoIncrement;

  int? steps;
  int? workoutMinutes;
  bool? isAsleep;
  
  @Index(unique: true, replace: true)
  DateTime? date;

  ActivityCache({
    this.steps = 0,
    this.workoutMinutes = 0,
    this.isAsleep = false,
    this.date,
  });
}

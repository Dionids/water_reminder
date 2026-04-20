import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 1)
class UserProfile extends HiveObject {
  @HiveField(0)
  double? weight;

  @HiveField(1)
  int? age;

  @HiveField(2)
  int? dailyBaseGoal;

  @HiveField(3)
  DateTime? lastSync;

  UserProfile({this.weight, this.age, this.dailyBaseGoal, this.lastSync});
}

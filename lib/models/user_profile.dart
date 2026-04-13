import 'package:isar/isar.dart';

part 'user_profile.g.dart';

@collection
class UserProfile {
  Id id = Isar.autoIncrement;

  double? weight;
  int? age;
  int? dailyBaseGoal;
  DateTime? lastSync;

  UserProfile({this.weight, this.age, this.dailyBaseGoal, this.lastSync});
}

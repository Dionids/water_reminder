import 'package:isar/isar.dart';

part 'user_profile.g.dart';

@collection
class UserProfile {
  Id id = Isar.autoIncrement;

  double? weight; // Weight in kg
  int? age;       // Age
  int dailyBaseGoal = 2000; // Base goal in ml
  
  DateTime lastSync = DateTime.now();
}

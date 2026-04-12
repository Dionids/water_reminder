import 'package:isar/isar.dart';

part 'water_log.g.dart';

@collection
class WaterLog {
  Id id = Isar.autoIncrement;

  int amountMl;      // Volume in ml
  DateTime dateTime; // Time of consumption
  String type;       // Type: "water", "coffee", "tea" etc.

  WaterLog({
    required this.amountMl,
    required this.dateTime,
    this.type = 'water',
  });
}

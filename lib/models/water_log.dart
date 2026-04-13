import 'package:isar/isar.dart';

part 'water_log.g.dart';

@collection
class WaterLog {
  Id id = Isar.autoIncrement;

  int? amountMl;
  
  @Index()
  DateTime? dateTime;

  String type = 'water';

  WaterLog({this.amountMl, this.dateTime, this.type = 'water'});
}

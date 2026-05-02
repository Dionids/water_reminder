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

  /// Уникальный идентификатор пользователя для API.
  /// Генерируется при первом сохранении профиля.
  @HiveField(4)
  String? userId;

  UserProfile({
    this.weight,
    this.age,
    this.dailyBaseGoal,
    this.lastSync,
    this.userId,
  });

  /// Возвращает userId или fallback-строку если не задан
  String get id => userId ?? 'user_local';
}

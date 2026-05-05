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

  /// Firebase UID — основной идентификатор пользователя.
  /// Устанавливается при первом входе (анонимном или через Google).
  /// Сохраняется при переустановке если вход через Google.
  @HiveField(4)
  String? firebaseUid;

  /// Android Device ID — резервный идентификатор.
  /// Позволяет восстановить профиль по устройству если Firebase недоступен.
  @HiveField(5)
  String? deviceId;

  /// Имя пользователя (из Google аккаунта или введённое вручную)
  @HiveField(6)
  String? displayName;

  /// Email (из Google аккаунта)
  @HiveField(7)
  String? email;

  /// Вошёл ли через Google (false = анонимный)
  @HiveField(8)
  bool isAnonymous;

  UserProfile({
    this.weight,
    this.age,
    this.dailyBaseGoal,
    this.lastSync,
    this.firebaseUid,
    this.deviceId,
    this.displayName,
    this.email,
    this.isAnonymous = true,
  });

  /// Основной ID для API запросов — всегда Firebase UID
  String get id => firebaseUid ?? deviceId ?? 'user_local';

  /// Отображаемое имя — Google имя или заглушка
  String get name => displayName ?? (isAnonymous ? 'Гость' : 'Пользователь');
}

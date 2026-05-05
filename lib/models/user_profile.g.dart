// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 1;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      weight:       fields[0] as double?,
      age:          fields[1] as int?,
      dailyBaseGoal: fields[2] as int?,
      lastSync:     fields[3] as DateTime?,
      firebaseUid:  fields[4] as String?,
      deviceId:     fields[5] as String?,
      displayName:  fields[6] as String?,
      email:        fields[7] as String?,
      isAnonymous:  fields[8] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.weight)
      ..writeByte(1)
      ..write(obj.age)
      ..writeByte(2)
      ..write(obj.dailyBaseGoal)
      ..writeByte(3)
      ..write(obj.lastSync)
      ..writeByte(4)
      ..write(obj.firebaseUid)
      ..writeByte(5)
      ..write(obj.deviceId)
      ..writeByte(6)
      ..write(obj.displayName)
      ..writeByte(7)
      ..write(obj.email)
      ..writeByte(8)
      ..write(obj.isAnonymous);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActivityCacheAdapter extends TypeAdapter<ActivityCache> {
  @override
  final int typeId = 2;

  @override
  ActivityCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActivityCache(
      date: fields[0] as DateTime,
      isAsleep: fields[1] as bool,
      stepCount: fields[2] as int,
      lastSyncTimestamp: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ActivityCache obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.isAsleep)
      ..writeByte(2)
      ..write(obj.stepCount)
      ..writeByte(3)
      ..write(obj.lastSyncTimestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

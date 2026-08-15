// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimeLogAdapter extends TypeAdapter<TimeLog> {
  @override
  final int typeId = 2;

  @override
  TimeLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeLog(
      timeLogId: fields[0] as String,
      projectId: fields[1] as String,
      startTime: fields[2] as int,
      endTime: fields[3] as int?,
      duration: fields[4] as double,
      isBillable: fields[5] as bool,
      billableAmount: fields[6] as double,
      tag: fields[7] as String,
      note: fields[8] as String,
      isDeleted: fields[9] as bool,
      syncStatus: fields[10] as int,
      serverUpdateTime: fields[11] as int?,
      createdAt: fields[12] as int,
      updatedAt: fields[13] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TimeLog obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.timeLogId)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.duration)
      ..writeByte(5)
      ..write(obj.isBillable)
      ..writeByte(6)
      ..write(obj.billableAmount)
      ..writeByte(7)
      ..write(obj.tag)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.isDeleted)
      ..writeByte(10)
      ..write(obj.syncStatus)
      ..writeByte(11)
      ..write(obj.serverUpdateTime)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_project.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClientProjectAdapter extends TypeAdapter<ClientProject> {
  @override
  final int typeId = 1;

  @override
  ClientProject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClientProject(
      projectId: fields[0] as String,
      clientName: fields[1] as String,
      clientEmail: fields[2] as String,
      projectName: fields[3] as String,
      hourlyRate: fields[4] as double,
      currency: fields[5] as String,
      status: fields[6] as String,
      isDeleted: fields[7] as bool,
      syncStatus: fields[8] as int,
      serverUpdateTime: fields[9] as int?,
      createdAt: fields[10] as int,
      updatedAt: fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ClientProject obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.projectId)
      ..writeByte(1)
      ..write(obj.clientName)
      ..writeByte(2)
      ..write(obj.clientEmail)
      ..writeByte(3)
      ..write(obj.projectName)
      ..writeByte(4)
      ..write(obj.hourlyRate)
      ..writeByte(5)
      ..write(obj.currency)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.isDeleted)
      ..writeByte(8)
      ..write(obj.syncStatus)
      ..writeByte(9)
      ..write(obj.serverUpdateTime)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientProjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserInfoAdapter extends TypeAdapter<UserInfo> {
  @override
  final int typeId = 0;

  @override
  UserInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserInfo(
      userId: fields[0] as String,
      userName: fields[1] as String,
      userEmail: fields[2] as String,
      currency: fields[3] as String,
      timezone: fields[4] as String,
      isPremium: fields[5] as bool,
      premiumType: fields[6] as String,
      expireTime: fields[7] as int?,
      trialEndTime: fields[8] as int?,
      lastSyncTime: fields[9] as int,
      createdAt: fields[10] as int,
      updatedAt: fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserInfo obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.userName)
      ..writeByte(2)
      ..write(obj.userEmail)
      ..writeByte(3)
      ..write(obj.currency)
      ..writeByte(4)
      ..write(obj.timezone)
      ..writeByte(5)
      ..write(obj.isPremium)
      ..writeByte(6)
      ..write(obj.premiumType)
      ..writeByte(7)
      ..write(obj.expireTime)
      ..writeByte(8)
      ..write(obj.trialEndTime)
      ..writeByte(9)
      ..write(obj.lastSyncTime)
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
      other is UserInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseLogAdapter extends TypeAdapter<ExpenseLog> {
  @override
  final int typeId = 3;

  @override
  ExpenseLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseLog(
      expenseId: fields[0] as String,
      projectId: fields[1] as String?,
      amount: fields[2] as double,
      currency: fields[3] as String,
      expenseDate: fields[4] as int,
      category: fields[5] as String,
      isTaxDeductible: fields[6] as bool,
      merchant: fields[7] as String,
      note: fields[8] as String,
      receiptUrl: fields[9] as String,
      isDeleted: fields[10] as bool,
      syncStatus: fields[11] as int,
      serverUpdateTime: fields[12] as int?,
      createdAt: fields[13] as int,
      updatedAt: fields[14] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseLog obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.expenseId)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.currency)
      ..writeByte(4)
      ..write(obj.expenseDate)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.isTaxDeductible)
      ..writeByte(7)
      ..write(obj.merchant)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.receiptUrl)
      ..writeByte(10)
      ..write(obj.isDeleted)
      ..writeByte(11)
      ..write(obj.syncStatus)
      ..writeByte(12)
      ..write(obj.serverUpdateTime)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

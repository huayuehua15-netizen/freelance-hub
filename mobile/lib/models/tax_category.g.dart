// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaxCategoryAdapter extends TypeAdapter<TaxCategory> {
  @override
  final int typeId = 4;

  @override
  TaxCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxCategory(
      categoryId: fields[0] as String,
      name: fields[1] as String,
      isDefault: fields[2] as bool,
      isTaxDeductibleDefault: fields[3] as bool,
      sortOrder: fields[4] as int,
      createdAt: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TaxCategory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.categoryId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isDefault)
      ..writeByte(3)
      ..write(obj.isTaxDeductibleDefault)
      ..writeByte(4)
      ..write(obj.sortOrder)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

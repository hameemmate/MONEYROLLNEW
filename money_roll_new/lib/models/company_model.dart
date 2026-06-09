import 'package:hive/hive.dart';

// TypeAdapterIds:
// CompanyModel = 0
// PaymentModel = 1
// TransferModel = 2
// CashTransactionModel = 3
// PaymentType = 4
// TransferSourceType = 5

class CompanyModel extends HiveObject {
  String id;
  String name;
  String? phone;
  String? notes;
  DateTime createdAt;
  bool isArchived;

  CompanyModel({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.createdAt,
    this.isArchived = false,
  });
}

class CompanyModelAdapter extends TypeAdapter<CompanyModel> {
  @override
  final int typeId = 0;

  @override
  CompanyModel read(BinaryReader reader) {
    return CompanyModel(
      id: reader.readString(),
      name: reader.readString(),
      phone: reader.read() as String?,
      notes: reader.read() as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      isArchived: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, CompanyModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.write(obj.phone);
    writer.write(obj.notes);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeBool(obj.isArchived);
  }
}

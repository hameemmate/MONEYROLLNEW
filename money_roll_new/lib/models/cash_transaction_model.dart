import 'package:hive/hive.dart';

enum CashTxType { add, deduct }

class CashTransactionModel extends HiveObject {
  String id;
  CashTxType txType;
  double amount;
  String description;
  String? relatedPaymentId;
  String? relatedTransferId;
  String? fromCompanyId; // who gave the cash
  DateTime date;
  DateTime createdAt;

  CashTransactionModel({
    required this.id,
    required this.txType,
    required this.amount,
    required this.description,
    this.relatedPaymentId,
    this.relatedTransferId,
    this.fromCompanyId,
    required this.date,
    required this.createdAt,
  });
}

class CashTxTypeAdapter extends TypeAdapter<CashTxType> {
  @override
  final int typeId = 6;

  @override
  CashTxType read(BinaryReader reader) => CashTxType.values[reader.readByte()];

  @override
  void write(BinaryWriter writer, CashTxType obj) =>
      writer.writeByte(obj.index);
}

class CashTransactionModelAdapter extends TypeAdapter<CashTransactionModel> {
  @override
  final int typeId = 3;

  @override
  CashTransactionModel read(BinaryReader reader) {
    return CashTransactionModel(
      id: reader.readString(),
      txType: CashTxType.values[reader.readByte()],
      amount: reader.readDouble(),
      description: reader.readString(),
      relatedPaymentId: reader.read() as String?,
      relatedTransferId: reader.read() as String?,
      fromCompanyId: reader.read() as String?,
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, CashTransactionModel obj) {
    writer.writeString(obj.id);
    writer.writeByte(obj.txType.index);
    writer.writeDouble(obj.amount);
    writer.writeString(obj.description);
    writer.write(obj.relatedPaymentId);
    writer.write(obj.relatedTransferId);
    writer.write(obj.fromCompanyId);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}

import 'package:hive/hive.dart';
import 'enums.dart';

/// Root payment record.
/// Every financial event starts here.
///
/// [type] received = money came TO me, sent = money went FROM me
/// [amount] total amount of this payment
/// [companyId] who I received from / sent to (null = free entry like "received cash")
/// [rootTransferId] first TransferModel id in the tree (the initial hop)
/// [description] what this payment is for
/// [remainingAmount] amount not yet forwarded in transfer chain (auto-calculated)
/// [totalDebt] sum of all debt amounts in entire transfer tree of this payment

class PaymentModel extends HiveObject {
  String id;
  PaymentType type;
  double amount;
  String? companyId;
  String? rootTransferId;
  String description;
  DateTime date;
  DateTime createdAt;
  double remainingAmount;
  double totalDebt;
  String? note;

  /// Auto-generated tree code for this payment, e.g. "M1", "M2".
  String code;

  /// Optional friendly name shown alongside the code.
  String? label;

  /// Optional deadline / due date for this payment.
  DateTime? deadline;

  PaymentModel({
    required this.id,
    required this.type,
    required this.amount,
    this.companyId,
    this.rootTransferId,
    required this.description,
    required this.date,
    required this.createdAt,
    required this.remainingAmount,
    this.totalDebt = 0.0,
    this.note,
    this.code = '',
    this.label,
    this.deadline,
  });

  /// Code plus label when present, e.g. "M1 · Office rent".
  String get displayTitle => (label != null && label!.trim().isNotEmpty)
      ? '$code · ${label!.trim()}'
      : code;
}

class PaymentModelAdapter extends TypeAdapter<PaymentModel> {
  @override
  final int typeId = 1;

  @override
  PaymentModel read(BinaryReader reader) {
    final id = reader.readString();
    final type = PaymentType.values[reader.readByte()];
    final amount = reader.readDouble();
    final companyId = reader.read() as String?;
    final rootTransferId = reader.read() as String?;
    final description = reader.readString();
    final date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final remainingAmount = reader.readDouble();
    final totalDebt = reader.readDouble();
    final note = reader.read() as String?;
    // New fields appended later; guard so older records still load.
    final code = reader.availableBytes > 0 ? reader.readString() : '';
    final label = reader.availableBytes > 0 ? reader.read() as String? : null;
    final deadlineMs = reader.availableBytes > 0 ? reader.read() as int? : null;
    return PaymentModel(
      id: id,
      type: type,
      amount: amount,
      companyId: companyId,
      rootTransferId: rootTransferId,
      description: description,
      date: date,
      createdAt: createdAt,
      remainingAmount: remainingAmount,
      totalDebt: totalDebt,
      note: note,
      code: code,
      label: label,
      deadline: deadlineMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deadlineMs),
    );
  }

  @override
  void write(BinaryWriter writer, PaymentModel obj) {
    writer.writeString(obj.id);
    writer.writeByte(obj.type.index);
    writer.writeDouble(obj.amount);
    writer.write(obj.companyId);
    writer.write(obj.rootTransferId);
    writer.writeString(obj.description);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeDouble(obj.remainingAmount);
    writer.writeDouble(obj.totalDebt);
    writer.write(obj.note);
    writer.writeString(obj.code);
    writer.write(obj.label);
    writer.write(obj.deadline?.millisecondsSinceEpoch);
  }
}

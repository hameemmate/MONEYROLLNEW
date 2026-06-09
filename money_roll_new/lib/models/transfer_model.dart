import 'package:hive/hive.dart';
import 'enums.dart';

/// Represents one hop in the payment chain.
/// A Transfer is always FROM a company/entity TO another company/entity.
///
/// Tree structure:
///   PaymentModel (root)
///     └── TransferModel (root transfer: YOU → A)
///           ├── TransferModel (A → B, sourceType=fromSpecific, specificParentId=rootTransferId)
///           └── TransferModel (A → C, sourceType=fromTotal)
///
/// [amount]          — how much was transferred in this hop
/// [fromCompanyId]   — null means "ME" (cash in hand)
/// [toCompanyId]     — null means "ME" (cash back to hand)
/// [parentTransferId] — parent transfer id in tree (null = root, parent is payment)
/// [paymentId]       — root payment this belongs to
/// [sourceType]      — fromSpecific: pulls from a specific parent's amount (locked slice)
///                     fromTotal: pulls from accumulated total at parent node
/// [specificParentTransferId] — only set when sourceType=fromSpecific
///                              identifies WHICH parent slice this came from
/// [note]            — optional memo
/// [isDebt]          — true when this transfer caused a negative balance at that entity
///                     e.g. A received 500 but forwarded 600 → debt=100 on A

class TransferModel extends HiveObject {
  String id;
  String paymentId;
  String? parentTransferId;
  double amount;
  String? fromCompanyId; // null = ME
  String? toCompanyId; // null = ME
  TransferSourceType sourceType;
  String? specificParentTransferId;
  String? note;
  DateTime createdAt;
  bool isDebt;
  double debtAmount; // how much exceeds available at this node

  /// Auto-generated tree code for this branch, e.g. "M1B1", "M1B1B2".
  String code;

  /// Optional friendly name for this branch, shown alongside the code.
  String? label;

  /// Optional deadline / due date for this branch.
  DateTime? deadline;

  TransferModel({
    required this.id,
    required this.paymentId,
    this.parentTransferId,
    required this.amount,
    this.fromCompanyId,
    this.toCompanyId,
    this.sourceType = TransferSourceType.fromTotal,
    this.specificParentTransferId,
    this.note,
    required this.createdAt,
    this.isDebt = false,
    this.debtAmount = 0.0,
    this.code = '',
    this.label,
    this.deadline,
  });

  /// Code plus label when present, e.g. "M1B1 · Salary share".
  String get displayCode => (label != null && label!.trim().isNotEmpty)
      ? '$code · ${label!.trim()}'
      : code;
}

class TransferModelAdapter extends TypeAdapter<TransferModel> {
  @override
  final int typeId = 2;

  @override
  TransferModel read(BinaryReader reader) {
    final id = reader.readString();
    final paymentId = reader.readString();
    final parentTransferId = reader.read() as String?;
    final amount = reader.readDouble();
    final fromCompanyId = reader.read() as String?;
    final toCompanyId = reader.read() as String?;
    final sourceType = TransferSourceType.values[reader.readByte()];
    final specificParentTransferId = reader.read() as String?;
    final note = reader.read() as String?;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final isDebt = reader.readBool();
    final debtAmount = reader.readDouble();
    // New fields appended later; guard so older records still load.
    final code = reader.availableBytes > 0 ? reader.readString() : '';
    final label = reader.availableBytes > 0 ? reader.read() as String? : null;
    final deadlineMs = reader.availableBytes > 0 ? reader.read() as int? : null;
    return TransferModel(
      id: id,
      paymentId: paymentId,
      parentTransferId: parentTransferId,
      amount: amount,
      fromCompanyId: fromCompanyId,
      toCompanyId: toCompanyId,
      sourceType: sourceType,
      specificParentTransferId: specificParentTransferId,
      note: note,
      createdAt: createdAt,
      isDebt: isDebt,
      debtAmount: debtAmount,
      code: code,
      label: label,
      deadline: deadlineMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deadlineMs),
    );
  }

  @override
  void write(BinaryWriter writer, TransferModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.paymentId);
    writer.write(obj.parentTransferId);
    writer.writeDouble(obj.amount);
    writer.write(obj.fromCompanyId);
    writer.write(obj.toCompanyId);
    writer.writeByte(obj.sourceType.index);
    writer.write(obj.specificParentTransferId);
    writer.write(obj.note);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeBool(obj.isDebt);
    writer.writeDouble(obj.debtAmount);
    writer.writeString(obj.code);
    writer.write(obj.label);
    writer.write(obj.deadline?.millisecondsSinceEpoch);
  }
}

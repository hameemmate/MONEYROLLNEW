import 'package:hive/hive.dart';

/// Where the money used to clear a debt comes from.
///
/// [pool]    — the originating payment pool's remaining (un-branched) balance.
/// [cash]    — cash in hand.
/// [company] — no money moves; the creditor company waives the shortfall
///             (a "remove the mistake" correction).
enum DebtClearSource { pool, cash, company }

/// A single settlement against a debt transfer.
///
/// A debt lives on the TransferModel that over-forwarded (isDebt/debtAmount).
/// Each clearance records part (or all) of that debt being settled, so a debt
/// can be cleared in installments. The creditor is the company that was short
/// (the debt transfer's fromCompanyId).
///
/// [transferId]  — the debt-bearing transfer this clears.
/// [paymentId]   — the pool that transfer belongs to.
/// [companyId]   — the creditor company (whom I owe).
/// [amount]      — amount cleared in this entry.
/// [source]      — pool / cash / company waive.
/// [cashTxId]    — id of the cash deduction created for pool/cash sources,
///                 kept so the entry can be reversed cleanly. Null for waives.
class DebtClearanceModel extends HiveObject {
  String id;
  String transferId;
  String paymentId;
  String companyId;
  double amount;
  DebtClearSource source;
  String? cashTxId;
  String? note;
  DateTime date;
  DateTime createdAt;

  DebtClearanceModel({
    required this.id,
    required this.transferId,
    required this.paymentId,
    required this.companyId,
    required this.amount,
    required this.source,
    this.cashTxId,
    this.note,
    required this.date,
    required this.createdAt,
  });
}

class DebtClearSourceAdapter extends TypeAdapter<DebtClearSource> {
  @override
  final int typeId = 8;

  @override
  DebtClearSource read(BinaryReader reader) =>
      DebtClearSource.values[reader.readByte()];

  @override
  void write(BinaryWriter writer, DebtClearSource obj) =>
      writer.writeByte(obj.index);
}

class DebtClearanceModelAdapter extends TypeAdapter<DebtClearanceModel> {
  @override
  final int typeId = 7;

  @override
  DebtClearanceModel read(BinaryReader reader) {
    return DebtClearanceModel(
      id: reader.readString(),
      transferId: reader.readString(),
      paymentId: reader.readString(),
      companyId: reader.readString(),
      amount: reader.readDouble(),
      source: DebtClearSource.values[reader.readByte()],
      cashTxId: reader.read() as String?,
      note: reader.read() as String?,
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, DebtClearanceModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.transferId);
    writer.writeString(obj.paymentId);
    writer.writeString(obj.companyId);
    writer.writeDouble(obj.amount);
    writer.writeByte(obj.source.index);
    writer.write(obj.cashTxId);
    writer.write(obj.note);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}

import 'package:hive/hive.dart';

enum PaymentType { received, sent }

enum TransferSourceType { fromSpecific, fromTotal }

class PaymentTypeAdapter extends TypeAdapter<PaymentType> {
  @override
  final int typeId = 4;

  @override
  PaymentType read(BinaryReader reader) {
    return PaymentType.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, PaymentType obj) {
    writer.writeByte(obj.index);
  }
}

class TransferSourceTypeAdapter extends TypeAdapter<TransferSourceType> {
  @override
  final int typeId = 5;

  @override
  TransferSourceType read(BinaryReader reader) {
    return TransferSourceType.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, TransferSourceType obj) {
    writer.writeByte(obj.index);
  }
}

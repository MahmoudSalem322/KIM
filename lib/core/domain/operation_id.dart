import 'package:uuid/uuid.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final class OperationId {
  const OperationId._(this.value);
  final String value;
  factory OperationId.generate() => OperationId._(const Uuid().v4());
  factory OperationId.parse(String value) {
    if (!_uuidV4.hasMatch(value)) {
      throw const FormatException('Expected a UUID v4 operation identifier');
    }
    return OperationId._(value);
  }
}

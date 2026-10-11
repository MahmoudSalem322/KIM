import 'dart:js_interop';

import 'package:kim/core/domain/money.dart';
import 'package:kim/core/domain/operation_id.dart';

@JS('kimMoneyResult')
external set result(JSString value);

void main() {
  try {
    final usd = Currency('USD', 2);
    check(
      (Money.parse('0.10', usd) + Money.parse('0.20', usd)).decimal == '0.30',
      'exact sum',
    );
    final huge = Money.parse('900719925474099312345.67', usd);
    check(
      huge.minorUnits.toString() == '90071992547409931234567',
      'JS safe integer boundary',
    );
    check(
      Money.fromJson(huge.toJson()) == huge,
      'string persistence roundtrip',
    );
    check(Money.parse('١٢٣٫٤٥', usd).decimal == '123.45', 'Arabic input');
    check(
      Money.parse('-0.01', usd).minorUnits == BigInt.from(-1),
      'negative minor unit',
    );
    var rejected = false;
    try {
      Money.parse('1.001', usd);
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'excess precision rejected');
    check(
      List.generate(500, (_) => OperationId.generate().value).toSet().length ==
          500,
      'UUID uniqueness',
    );
    result = '7 JavaScript money/ID checks passed'.toJS;
  } catch (error) {
    result = 'FAILED: $error'.toJS;
    rethrow;
  }
}

void check(bool condition, String name) {
  if (!condition) throw StateError(name);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/core/domain/operation_id.dart';

void main() {
  final usd = Currency('USD', 2);
  test('decimal addition is exact', () {
    expect(
      (Money.parse('0.10', usd) + Money.parse('0.20', usd)).decimal,
      '0.30',
    );
  });
  test('huge amounts survive storage without JS number conversion', () {
    final money = Money.parse('900719925474099312345.67', usd);
    expect(money.minorUnits.toString(), '90071992547409931234567');
    expect(Money.fromJson(money.toJson()), money);
  });
  test('Arabic digits and decimal separator parse exactly', () {
    expect(Money.parse('١٢٣٫٤٥', usd).decimal, '123.45');
    expect(Money.parse('-0.01', usd).minorUnits, BigInt.from(-1));
  });
  test('reject rounding, exponent, grouping and invalid input', () {
    for (final value in ['1.001', '1e3', '1,000', '', 'NaN', '.2', '1.']) {
      expect(() => Money.parse(value, usd), throwsFormatException);
    }
  });
  test('scale zero and three and negative formatting', () {
    expect(Money.parse('15', Currency('JPY', 0)).decimal, '15');
    expect(Money.parse('-1.002', Currency('KWD', 3)).decimal, '-1.002');
    expect(Money.parse('1.2', usd).decimal, '1.20');
  });
  test('cannot mix currencies or scales', () {
    expect(
      () => Money.parse('1', usd) + Money.parse('1', Currency('EUR', 2)),
      throwsArgumentError,
    );
    expect(
      () => Money.parse('1', usd) - Money.parse('1', Currency('USD', 3)),
      throwsArgumentError,
    );
    expect(() => Currency('usd', 2), throwsArgumentError);
    expect(() => Currency('USD', -1), throwsArgumentError);
  });
  test('operation IDs are validated UUID v4 and unique', () {
    final ids = List.generate(500, (_) => OperationId.generate().value);
    expect(ids.toSet().length, 500);
    expect(OperationId.parse(ids.first).value, ids.first);
    expect(() => OperationId.parse('not-an-id'), throwsFormatException);
  });
}

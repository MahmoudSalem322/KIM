import '../../../core/domain/money.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transfers/domain/exchange_rate.dart';

/// A user documented valuation quote, not a historical transaction mutation.
final class ManualRate {
  ManualRate({
    required this.from,
    required this.to,
    required String decimal,
    required String source,
    required this.asOf,
    required this.updatedAt,
  }) : decimal = ExchangeRate.parse(decimal).decimal,
       source = source.trim() {
    if (from.code == to.code ||
        this.source.isEmpty ||
        this.source.length > 160 ||
        !validTransactionDate(asOf)) {
      throw const FormatException('Invalid documented exchange rate');
    }
  }
  final Currency from, to;
  final String decimal, source, asOf;
  final DateTime updatedAt;
  String get key => '${from.code}/${from.scale}:${to.code}/${to.scale}';
  Map<String, Object?> toJson() => {
    'from': from.code,
    'fromScale': from.scale,
    'to': to.code,
    'toScale': to.scale,
    'decimal': decimal,
    'source': source,
    'asOf': asOf,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
  factory ManualRate.fromJson(Map<String, Object?> j) => ManualRate(
    from: Currency(j['from'] as String, j['fromScale'] as int),
    to: Currency(j['to'] as String, j['toScale'] as int),
    decimal: j['decimal'] as String,
    source: j['source'] as String,
    asOf: j['asOf'] as String,
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );
}

final class ConvertedMoney {
  const ConvertedMoney(this.amount, {this.rate, this.inverse = false});
  final Money amount;
  final ManualRate? rate;
  final bool inverse;
}

/// The current saved quote set values both periods equally. No triangulation,
/// live prices or implicit defaults; missing pairs produce incomplete reports.
final class ExchangeBook {
  ExchangeBook({
    required this.currency,
    required List<ManualRate> rates,
    this.revision = 0,
  }) : rates = List.unmodifiable(rates) {
    final pairs = <String>{};
    for (final rate in rates) {
      final pair = [
        '${rate.from.code}/${rate.from.scale}',
        '${rate.to.code}/${rate.to.scale}',
      ]..sort();
      if (!pairs.add(pair.join(':'))) {
        throw const FormatException('Duplicate or conflicting rate pair');
      }
    }
  }
  final Currency currency;
  final List<ManualRate> rates;
  final int revision;
  ConvertedMoney? convert(Money original) {
    if (original.currency == currency) return ConvertedMoney(original);
    for (final rate in rates) {
      final direct = rate.from == original.currency && rate.to == currency;
      final inverse = rate.to == original.currency && rate.from == currency;
      if (!direct && !inverse) continue;
      final quote = ExchangeRate.parse(rate.decimal);
      final numerator = inverse ? quote.denominator : quote.numerator;
      final denominator = inverse ? quote.numerator : quote.denominator;
      final n =
          original.minorUnits.abs() *
          numerator *
          BigInt.from(10).pow(currency.scale);
      final d = denominator * BigInt.from(10).pow(original.currency.scale);
      final units =
          n ~/ d + ((n % d) * BigInt.two >= d ? BigInt.one : BigInt.zero);
      return ConvertedMoney(
        Money(original.minorUnits.isNegative ? -units : units, currency),
        rate: rate,
        inverse: inverse,
      );
    }
    return null;
  }
}

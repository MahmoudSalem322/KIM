import '../../../core/domain/money.dart';

/// Exact decimal quote: one source unit buys [decimal] destination units.
final class ExchangeRate {
  ExchangeRate._(this.numerator, this.denominator, this.decimal);
  final BigInt numerator, denominator;
  final String decimal;
  factory ExchangeRate.parse(String text) {
    var value = text.trim().replaceAll('٫', '.');
    for (var i = 0; i < 10; i++) {
      value = value
          .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
          .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
    }
    if (!RegExp(r'^\d+(\.\d{1,12})?$').hasMatch(value)) {
      throw const FormatException('Positive decimal rate, maximum 12 places');
    }
    final parts = value.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    final n = BigInt.parse('${parts[0]}$fraction');
    if (n <= BigInt.zero) throw const FormatException('Rate must be positive');
    final normalized = fraction.replaceFirst(RegExp(r'0+$'), '');
    return ExchangeRate._(
      n,
      BigInt.from(10).pow(fraction.length),
      '${BigInt.parse(parts[0])}${normalized.isEmpty ? '' : '.$normalized'}',
    );
  }
  Money convert(Money amount, Currency destination) {
    if (amount.minorUnits < BigInt.zero) {
      throw ArgumentError('Positive quote only');
    }
    final n =
        amount.minorUnits * numerator * BigInt.from(10).pow(destination.scale);
    final d = denominator * BigInt.from(10).pow(amount.currency.scale);
    final rounded =
        n ~/ d + ((n % d) * BigInt.two >= d ? BigInt.one : BigInt.zero);
    return Money(rounded, destination);
  }
}

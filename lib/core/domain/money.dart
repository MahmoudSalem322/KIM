final _currencyCode = RegExp(r'^[A-Z]{3}$');
final _exactDecimal = RegExp(r'^-?\d+(\.\d+)?$');

/// Currency scale is explicit: do not infer it from locale or exchange rates.
final class Currency {
  Currency(this.code, this.scale) {
    if (!_currencyCode.hasMatch(code) || scale < 0 || scale > 6) {
      throw ArgumentError('Invalid currency code or minor-unit scale');
    }
  }
  final String code;
  final int scale;
  @override
  bool operator ==(Object other) =>
      other is Currency && code == other.code && scale == other.scale;
  @override
  int get hashCode => Object.hash(code, scale);
}

/// Exact, immutable amounts, including values beyond JavaScript safe integers.
final class Money {
  const Money(this.minorUnits, this.currency);
  final BigInt minorUnits;
  final Currency currency;

  factory Money.parse(String text, Currency currency) {
    var normalized = text.trim().replaceAll('٫', '.');
    for (var i = 0; i < 10; i++) {
      normalized = normalized
          .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
          .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
    }
    if (!_exactDecimal.hasMatch(normalized)) {
      throw const FormatException('Enter an exact decimal amount');
    }
    final negative = normalized.startsWith('-');
    final parts = normalized.replaceFirst('-', '').split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.length > currency.scale) {
      throw const FormatException('Amount exceeds currency precision');
    }
    final units = BigInt.parse(
      '${parts[0]}${fraction.padRight(currency.scale, '0')}',
    );
    return Money(negative ? -units : units, currency);
  }

  String get decimal {
    final digits = minorUnits.abs().toString().padLeft(currency.scale + 1, '0');
    final sign = minorUnits.isNegative ? '-' : '';
    if (currency.scale == 0) return '$sign$digits';
    final split = digits.length - currency.scale;
    return '$sign${digits.substring(0, split)}.${digits.substring(split)}';
  }

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  void _requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Currency and scale must match');
    }
  }

  Map<String, Object?> toJson() => {
    'minorUnits': minorUnits.toString(),
    'currency': currency.code,
    'scale': currency.scale,
  };
  factory Money.fromJson(Map<String, Object?> json) => Money(
    BigInt.parse(json['minorUnits'] as String),
    Currency(json['currency'] as String, json['scale'] as int),
  );
  @override
  bool operator ==(Object other) =>
      other is Money &&
      minorUnits == other.minorUnits &&
      currency == other.currency;
  @override
  int get hashCode => Object.hash(minorUnits, currency);
}

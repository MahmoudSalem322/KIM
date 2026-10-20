import 'package:flutter_test/flutter_test.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';

void main() {
  test('calendar dates accept real days in range only', () {
    for (final valid in [
      '1900-01-01',
      '2024-02-29',
      '2026-10-20',
      '2026-12-31',
      '2100-12-31',
    ]) {
      expect(validTransactionDate(valid), true, reason: valid);
    }
    for (final invalid in [
      '',
      '1899-12-31',
      '2101-01-01',
      '2025-02-29',
      '2100-02-29',
      '2026-04-31',
      '2026-13-01',
      '2026-00-10',
      '2026-01-00',
      '2026-1-01',
      '2026-01-01T00:00',
      ' 2026-01-01',
      '٢٠٢٦-٠١-٠١',
      '2026/01/01',
    ]) {
      expect(validTransactionDate(invalid), false, reason: invalid);
    }
  });

  test('calendarDate round-trips every valid day of a leap year', () {
    var day = DateTime(2024);
    while (day.year == 2024) {
      expect(validTransactionDate(calendarDate(day)), true);
      day = DateTime(day.year, day.month, day.day + 1);
    }
  });
}

import '../../../core/domain/money.dart';
import '../../reports/domain/exchange_book.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';

/// Calendar boundaries are local dates, matching persisted transaction dates.
final class DashboardPeriod {
  DashboardPeriod(DateTime start, DateTime end)
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day) {
    if (this.end.isBefore(this.start)) throw ArgumentError('Invalid period');
  }
  final DateTime start, end;
  String get from => calendarDate(start);
  String get to => calendarDate(end);
  bool contains(String date) =>
      date.compareTo(from) >= 0 && date.compareTo(to) <= 0;

  factory DashboardPeriod.preset(String preset, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (preset) {
      'week' => DashboardPeriod(
        DateTime(today.year, today.month, today.day - 6),
        today,
      ),
      'lastMonth' => DashboardPeriod(
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month, 0),
      ),
      'year' => DashboardPeriod(DateTime(now.year), DateTime(now.year, 12, 31)),
      _ => DashboardPeriod(
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1, 0),
      ),
    };
  }
}

final class DashboardBucket {
  DashboardBucket(this.from, this.to, this.income, this.expense);
  final String from, to;
  final Money income, expense;
}

final class DashboardSummary {
  DashboardSummary({
    required List<WalletSnapshot> wallets,
    required List<FinancialTransaction> transactions,
    required this.currency,
    required this.period,
    ExchangeBook? exchangeBook,
  }) {
    final book = ExchangeBook(
      currency: currency,
      rates: exchangeBook?.rates ?? [],
    );
    final active = wallets.where((w) => !w.wallet.archived).toList();
    activeCount = active.length;
    final selected = transactions
        .where((t) => !t.deleted && period.contains(t.date))
        .toList();
    final missing = <Currency>{};
    Money? convert(Money amount) {
      final converted = book.convert(amount)?.amount;
      if (converted == null) missing.add(amount.currency);
      return converted;
    }

    final converted = <String, Money>{};
    for (final t in selected) {
      final amount = convert(t.draft.amount);
      if (amount != null) converted[t.id] = amount;
    }
    final relevantIds = selected.map((t) => t.walletId).toSet();
    final knownIds = wallets.map((w) => w.wallet.id).toSet();
    concealed =
        !knownIds.containsAll(relevantIds) ||
        wallets.any(
          (w) =>
              w.wallet.hidden &&
              (!w.wallet.archived || relevantIds.contains(w.wallet.id)),
        );
    balance = active.fold(
      Money(BigInt.zero, currency),
      (sum, w) => sum + (convert(w.balance) ?? Money(BigInt.zero, currency)),
    );
    excludedCurrencies = missing.toList()
      ..sort(
        (a, b) => '${a.code}/${a.scale}'.compareTo('${b.code}/${b.scale}'),
      );
    var incoming = BigInt.zero, outgoing = BigInt.zero;
    final grouped = <String, BigInt>{};
    for (final t in selected) {
      final amount = converted[t.id];
      if (amount == null) continue;
      if (t.draft.kind == TransactionKind.income) {
        incoming += amount.minorUnits;
      } else {
        outgoing += amount.minorUnits;
        grouped.update(
          t.draft.category,
          (v) => v + amount.minorUnits,
          ifAbsent: () => amount.minorUnits,
        );
      }
    }
    income = Money(incoming, currency);
    expense = Money(outgoing, currency);
    net = income - expense;
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final amount = b.value.compareTo(a.value);
        return amount == 0 ? a.key.compareTo(b.key) : amount;
      });
    categories = {for (final e in entries) e.key: Money(e.value, currency)};
    // Use UTC only to count calendar days; DST cannot change bucket boundaries.
    final start = DateTime.utc(
      period.start.year,
      period.start.month,
      period.start.day,
    );
    final end = DateTime.utc(period.end.year, period.end.month, period.end.day);
    final days = end.difference(start).inDays + 1;
    final step = (days / 12).ceil();
    final ins = List.generate((days / step).ceil(), (_) => BigInt.zero);
    final outs = List.generate(ins.length, (_) => BigInt.zero);
    for (final t in selected) {
      final amount = converted[t.id];
      if (amount == null) continue;
      final date = DateTime.parse('${t.date}T00:00:00Z');
      final index = date.difference(start).inDays ~/ step;
      if (t.draft.kind == TransactionKind.income) {
        ins[index] += amount.minorUnits;
      } else {
        outs[index] += amount.minorUnits;
      }
    }
    buckets = List.generate(ins.length, (i) {
      final last = (i + 1) * step - 1;
      return DashboardBucket(
        calendarDate(start.add(Duration(days: i * step))),
        calendarDate(start.add(Duration(days: last < days ? last : days - 1))),
        Money(ins[i], currency),
        Money(outs[i], currency),
      );
    });
  }
  final Currency currency;
  final DashboardPeriod period;
  late final Money balance, income, expense, net;
  late final bool concealed;
  late final int activeCount;
  late final List<Currency> excludedCurrencies;
  late final Map<String, Money> categories;
  late final List<DashboardBucket> buckets;
}

/// Only bounded drawing coordinates use doubles; financial totals stay BigInt.
double chartFraction(BigInt value, BigInt total) => total <= BigInt.zero
    ? 0
    : ((value * BigInt.from(1000000)) ~/ total).toInt().clamp(0, 1000000) /
          1000000;

import '../../../core/domain/money.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transfers/domain/wallet_transfer.dart';
import '../../debts/domain/debt.dart';
import '../../wallets/domain/wallet.dart';
import 'exchange_book.dart';

final class ReportFilter {
  ReportFilter({
    required this.from,
    required this.to,
    this.walletId,
    this.category,
  }) {
    if (!validTransactionDate(from) ||
        !validTransactionDate(to) ||
        from.compareTo(to) > 0) {
      throw ArgumentError('Invalid report range');
    }
  }
  final String from, to;
  ReportFilter._comparison({
    required this.from,
    required this.to,
    this.walletId,
    this.category,
  });
  final String? walletId, category;
  bool contains(String date) =>
      date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
  int get days =>
      DateTime.parse('${to}T00:00:00Z')
          .difference(DateTime.parse('${from}T00:00:00Z'))
          .inDays +
      1;
  ReportFilter get previous {
    final end = DateTime.parse('${from}T00:00:00Z')
        .subtract(const Duration(days: 1));
    return ReportFilter._comparison(
      from: calendarDate(end.subtract(Duration(days: days - 1))),
      to: calendarDate(end),
      walletId: walletId,
      category: category,
    );
  }
}

enum ReportRowKind { income, expense, debtIn, debtOut, transferIn, transferOut }

final class ReportRow {
  const ReportRow({
    required this.id,
    required this.date,
    required this.walletId,
    required this.kind,
    required this.original,
    required this.conversion,
    this.category = '',
    this.notes = '',
    this.internalTransfer = false,
  });
  final String id, date, walletId, category, notes;
  final ReportRowKind kind;

  /// Signed cash movement in immutable original transaction currency.
  final Money original;
  final ConvertedMoney? conversion;
  final bool internalTransfer;
  Money? get converted => conversion?.amount;
}

final class ReportTotals {
  ReportTotals(List<ReportRow> rows, Currency currency) {
    var i = BigInt.zero,
        e = BigInt.zero,
        d = BigInt.zero,
        t = BigInt.zero,
        v = BigInt.zero;
    for (final row in rows) {
      final value = row.converted?.minorUnits;
      if (value == null) continue;
      switch (row.kind) {
        case ReportRowKind.income:
          i += value;
        case ReportRowKind.expense:
          e -= value;
        case ReportRowKind.debtIn:
        case ReportRowKind.debtOut:
          d += value;
        case ReportRowKind.transferIn:
        case ReportRowKind.transferOut:
          if (row.internalTransfer) {
            v += value;
          } else {
            t += value;
          }
      }
    }
    income = Money(i, currency);
    expense = Money(e, currency);
    operatingNet = income - expense;
    debtNet = Money(d, currency);
    transferNet = Money(t, currency);
    cashFlow = operatingNet + debtNet + transferNet;
    transferValuationDifference = Money(v, currency);
    missingCurrencies = {
      for (final r in rows)
        if (r.conversion == null) r.original.currency,
    };
  }
  late final Money income,
      expense,
      operatingNet,
      debtNet,
      transferNet,
      cashFlow;
  late final Money transferValuationDifference;
  late final Set<Currency> missingCurrencies;
  bool get complete => missingCurrencies.isEmpty;
}

final class ReportBucket {
  const ReportBucket(this.from, this.to, this.totals);
  final String from, to;
  final ReportTotals totals;
  Money get income => totals.income;
  Money get expense => totals.expense;
  Money get cashFlow => totals.cashFlow;
}

/// Uses current effective records, never sums ledger append/reversal history.
/// Transfers have creation dates because phase 4 has no effective-date field.
/// Opening balances/adjustments and administrative debts are not cash activity.
final class ReportResult {
  ReportResult.calculate({
    required this.filter,
    required this.book,
    required List<WalletSnapshot> wallets,
    required List<FinancialTransaction> transactions,
    required List<WalletTransfer> transfers,
    required List<DebtSnapshot> debts,
  }) {
    final previousFilter = filter.previous;
    final all = <ReportRow>[];
    void add(
      String id,
      String date,
      String walletId,
      ReportRowKind kind,
      Money amount, {
      String category = '',
      String notes = '',
      bool internalTransfer = false,
    }) {
      if (filter.walletId != null && filter.walletId != walletId ||
          filter.category != null && filter.category != category ||
          !filter.contains(date) && !previousFilter.contains(date)) {
        return;
      }
      all.add(
        ReportRow(
          id: id,
          date: date,
          walletId: walletId,
          kind: kind,
          original: amount,
          conversion: book.convert(amount),
          category: category,
          notes: notes,
          internalTransfer: internalTransfer,
        ),
      );
    }

    for (final t in transactions.where((t) => !t.deleted)) {
      add(
        t.id,
        t.date,
        t.walletId,
        t.draft.kind == TransactionKind.income
            ? ReportRowKind.income
            : ReportRowKind.expense,
        t.draft.effect,
        category: t.draft.category,
        notes: t.draft.notes,
      );
    }
    for (final t in transfers.where((t) => !t.cancelled)) {
      final date = calendarDate(t.createdAt.toLocal());
      add(
        '${t.id}:out',
        date,
        t.draft.sourceId,
        ReportRowKind.transferOut,
        Money(-t.draft.amount.minorUnits, t.draft.amount.currency),
        notes: t.draft.notes,
        internalTransfer: filter.walletId == null,
      );
      add(
        '${t.id}:in',
        date,
        t.draft.destinationId,
        ReportRowKind.transferIn,
        t.received,
        notes: t.draft.notes,
        internalTransfer: filter.walletId == null,
      );
    }
    for (final d in debts) {
      for (final event in d.events.where((e) => !e.cancelled)) {
        final effect = event.draft.effect(d.debt.draft.direction);
        add(
          event.id,
          event.draft.date,
          event.draft.walletId,
          effect.minorUnits.isNegative
              ? ReportRowKind.debtOut
              : ReportRowKind.debtIn,
          effect,
          notes: event.draft.note,
        );
      }
    }
    all.sort((a, b) {
      final date = a.date.compareTo(b.date);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
    rows = List.unmodifiable(all.where((r) => filter.contains(r.date)));
    totals = ReportTotals(rows, book.currency);
    previous = ReportTotals(
      all.where((r) => previousFilter.contains(r.date)).toList(),
      book.currency,
    );
    relevantWalletIds = Set.unmodifiable(all.map((r) => r.walletId));
    // Fail closed while independent repository streams are catching up, or if
    // imported data references a wallet whose privacy state is unavailable.
    concealed = concealedBy(wallets);
    missingCurrencies = {
      ...totals.missingCurrencies,
      ...previous.missingCurrencies,
    };
    final grouped = <String, Money>{};
    for (final row in rows) {
      if (row.kind != ReportRowKind.expense || row.converted == null) continue;
      final amount = Money(-row.converted!.minorUnits, book.currency);
      grouped.update(row.category, (v) => v + amount, ifAbsent: () => amount);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.minorUnits.compareTo(a.value.minorUnits));
    categories = Map.unmodifiable({for (final e in entries) e.key: e.value});
    final step = (filter.days + 11) ~/ 12;
    final start = DateTime.parse('${filter.from}T00:00:00Z');
    buckets = List.unmodifiable(
      List.generate((filter.days + step - 1) ~/ step, (i) {
        final from = calendarDate(start.add(Duration(days: i * step)));
        final last = ((i + 1) * step - 1).clamp(0, filter.days - 1);
        final to = calendarDate(start.add(Duration(days: last)));
        return ReportBucket(
          from,
          to,
          ReportTotals(
            rows
                .where(
                  (r) =>
                      r.date.compareTo(from) >= 0 && r.date.compareTo(to) <= 0,
                )
                .toList(),
            book.currency,
          ),
        );
      }),
    );
  }
  final ReportFilter filter;
  final ExchangeBook book;
  late final Set<String> relevantWalletIds;
  bool concealedBy(List<WalletSnapshot> wallets) =>
      !wallets.map((w) => w.wallet.id).toSet().containsAll(relevantWalletIds) ||
      wallets.any(
        (w) => w.wallet.hidden && relevantWalletIds.contains(w.wallet.id),
      );
  late final List<ReportRow> rows;
  late final ReportTotals totals, previous;
  late final bool concealed;
  late final Set<Currency> missingCurrencies;
  late final Map<String, Money> categories;
  late final List<ReportBucket> buckets;
  Currency get currency => book.currency;
  Money get income => totals.income;
  Money get expense => totals.expense;
  Money get operatingNet => totals.operatingNet;
  Money get debtNet => totals.debtNet;
  Money get transferNet => totals.transferNet;
  Money get cashFlow => totals.cashFlow;
  bool get complete => missingCurrencies.isEmpty;
}

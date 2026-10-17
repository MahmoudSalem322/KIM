import '../../budgets/domain/budget.dart';
import '../../debts/domain/debt.dart';
import '../../recurring/domain/recurring_payment.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';

enum NoticeKind { subscription, blocked, recorded, reversed, budget, debt }

final class Notice {
  const Notice({
    required this.id,
    required this.kind,
    required this.name,
    required this.date,
    required this.route,
    this.detail = '',
  });
  final String id, name, date, route, detail;
  final NoticeKind kind;
}

/// Current facts, not stale stored financial messages. Removed/edited expenses
/// immediately remove obsolete budget alerts; read state is stored separately.
List<Notice> deriveNotices({
  required DateTime now,
  required List<RecurringPayment> schedules,
  required List<RecurringOccurrence> occurrences,
  required List<Budget> budgets,
  required List<DebtSnapshot> debts,
  required List<FinancialTransaction> transactions,
  required List<WalletSnapshot> wallets,
}) {
  final result = <Notice>[],
      today = calendarDate(now),
      soon = calendarDate(DateTime(now.year, now.month, now.day + 7));
  final ws = {for (final w in wallets) w.wallet.id: w},
      plans = {for (final p in schedules) p.id: p},
      tx = {for (final t in transactions) t.id: t};
  for (final p in schedules.where(
    (p) =>
        p.status == RecurringStatus.active &&
        p.draft.nextDate.compareTo(soon) <= 0,
  )) {
    if (ws[p.draft.walletId]?.wallet.hidden != false) continue;
    final blocked = p.lastError.isNotEmpty;
    result.add(
      Notice(
        id: '${blocked ? 'blocked' : 'subscription'}:${p.id}:${p.draft.nextDate}${blocked ? ':${p.lastError}' : ''}',
        kind: blocked ? NoticeKind.blocked : NoticeKind.subscription,
        name: p.draft.name,
        date: p.draft.nextDate,
        route: '/recurring',
        detail: p.lastError,
      ),
    );
  }
  final recent =
      occurrences
          .where(
            (o) =>
                o.date.compareTo(
                      calendarDate(DateTime(now.year, now.month, now.day - 7)),
                    ) >=
                    0 &&
                o.date.compareTo(today) <= 0,
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  for (final o in recent.take(100)) {
    final p = plans[o.scheduleId], t = tx[o.transactionId];
    if (p == null || t == null || ws[t.walletId]?.wallet.hidden != false) {
      continue;
    }
    result.add(
      Notice(
        id: '${t.deleted ? 'reversed' : 'recorded'}:${o.id}',
        kind: t.deleted ? NoticeKind.reversed : NoticeKind.recorded,
        name: p.draft.name,
        date: o.date,
        route: '/transactions',
      ),
    );
  }
  for (final b in budgets.where((b) => !b.archived)) {
    final u = BudgetUsage(b, now, transactions, wallets);
    if (u.concealed || u.crossed == null) continue;
    result.add(
      Notice(
        id: 'budget:${b.id}:${u.period.from}:${u.crossed}',
        kind: NoticeKind.budget,
        name: b.draft.name,
        date: u.period.from,
        route: '/budgets',
        detail: '${u.crossed}%',
      ),
    );
  }
  for (final d in debts) {
    if (d.concealed(wallets) ||
        d.remaining.minorUnits == BigInt.zero ||
        d.debt.draft.dueOn.compareTo(soon) > 0) {
      continue;
    }
    result.add(
      Notice(
        id: 'debt:${d.debt.id}:${d.debt.draft.dueOn}',
        kind: NoticeKind.debt,
        name: d.debt.draft.person,
        date: d.debt.draft.dueOn,
        route: '/debts',
        detail: d.status(now).name,
      ),
    );
  }
  result.sort((a, b) {
    final d = a.date.compareTo(b.date);
    return d != 0 ? d : a.id.compareTo(b.id);
  });
  return List.unmodifiable(result);
}

final class NoticePreferences {
  const NoticePreferences({
    this.enabled = false,
    this.read = const {},
    this.dismissed = const {},
  });
  final bool enabled;
  final Set<String> read, dismissed;
}

/// Group reminders by calendar day: generic OS notifications never contain
/// wallet balances, amounts, subscription names or debtor identities.
List<String> reminderDates(
  DateTime now,
  List<RecurringPayment> plans,
  List<DebtSnapshot> debts,
) {
  final from = calendarDate(DateTime(now.year, now.month, now.day + 1)),
      to = calendarDate(DateTime(now.year, now.month, now.day + 30));
  final dates = <String>{};
  for (final p in plans) {
    dates.addAll(p.datesIn(from, to));
    // Monthly 31-day and yearly subscriptions still need their next alarm
    // when it lies beyond the rolling near-term window.
    dates.addAll(p.datesIn(from, '2100-12-31', limit: 1));
  }
  for (final d in debts) {
    if (d.remaining.minorUnits > BigInt.zero &&
        d.debt.draft.dueOn.compareTo(from) >= 0 &&
        d.debt.draft.dueOn.compareTo('2100-12-31') <= 0) {
      dates.add(d.debt.draft.dueOn);
    }
  }
  final sorted = dates.toList()..sort();
  return sorted.take(60).toList(growable: false);
}

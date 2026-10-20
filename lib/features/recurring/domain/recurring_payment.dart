import '../../../core/domain/money.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';

enum RecurringCycle { daily, weekly, monthly, yearly }

enum RecurringStatus { active, paused, cancelled, finished }

final class RecurringDraft {
  RecurringDraft({
    required String name,
    required this.amount,
    required this.walletId,
    required this.cycle,
    required this.nextDate,
    required this.category,
    this.automatic = false,
  }) : name = name.trim();
  final String name, walletId, nextDate, category;
  final Money amount;
  final RecurringCycle cycle;
  final bool automatic;
  void validate() {
    if (name.isEmpty ||
        name.length > 80 ||
        amount.minorUnits <= BigInt.zero ||
        walletId.isEmpty ||
        category.isEmpty ||
        !validTransactionDate(nextDate)) {
      throw const WalletFailure('invalidRecurring');
    }
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'amount': amount.toJson(),
    'walletId': walletId,
    'cycle': cycle.name,
    'nextDate': nextDate,
    'category': category,
    'automatic': automatic,
  };
  factory RecurringDraft.fromJson(Map<String, Object?> v) => RecurringDraft(
    name: v['name'] as String,
    amount: Money.fromJson(Map<String, Object?>.from(v['amount'] as Map)),
    walletId: v['walletId'] as String,
    cycle: RecurringCycle.values.byName(v['cycle'] as String),
    nextDate: v['nextDate'] as String,
    category: v['category'] as String,
    automatic: v['automatic'] as bool,
  )..validate();
}

final class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.draft,
    required this.status,
    required this.revision,
    required this.anchorDay,
    required this.anchorMonth,
    this.lastPaidDate = '',
    this.lastError = '',
  });
  final String id, lastPaidDate, lastError;
  final RecurringDraft draft;
  final RecurringStatus status;
  final int revision, anchorDay, anchorMonth;
  Map<String, Object?> toJson() => {
    ...draft.toJson(),
    'status': status.name,
    'revision': revision,
    'anchorDay': anchorDay,
    'anchorMonth': anchorMonth,
    'lastPaidDate': lastPaidDate,
    'lastError': lastError,
  };
  factory RecurringPayment.fromJson(String id, Map<String, Object?> v) =>
      RecurringPayment(
        id: id,
        draft: RecurringDraft.fromJson(v),
        status: RecurringStatus.values.byName(v['status'] as String),
        revision: v['revision'] as int,
        anchorDay: v['anchorDay'] as int,
        anchorMonth: v['anchorMonth'] as int,
        lastPaidDate: v['lastPaidDate'] as String,
        lastError: v['lastError'] as String,
      );
  String? after(String date) {
    final at = DateTime.parse('${date}T00:00:00Z');
    DateTime next;
    switch (draft.cycle) {
      case RecurringCycle.daily:
        next = at.add(const Duration(days: 1));
      case RecurringCycle.weekly:
        next = at.add(const Duration(days: 7));
      case RecurringCycle.monthly:
        final month = DateTime.utc(at.year, at.month + 1);
        final last = DateTime.utc(month.year, month.month + 1, 0).day;
        next = DateTime.utc(
          month.year,
          month.month,
          anchorDay > last ? last : anchorDay,
        );
      case RecurringCycle.yearly:
        final last = DateTime.utc(at.year + 1, anchorMonth + 1, 0).day;
        next = DateTime.utc(
          at.year + 1,
          anchorMonth,
          anchorDay > last ? last : anchorDay,
        );
    }
    return next.year > 2100 ? null : calendarDate(next);
  }

  List<String> datesIn(String from, String to, {int limit = 400}) {
    if (status != RecurringStatus.active) return const [];
    final dates = <String>[];
    String? date = draft.nextDate;
    for (var i = 0; i < 80000 && date != null && date.compareTo(to) <= 0; i++) {
      if (date.compareTo(from) >= 0) {
        dates.add(date);
        if (dates.length >= limit) break;
      }
      date = after(date);
    }
    return List.unmodifiable(dates);
  }
}

final class RecurringOccurrence {
  const RecurringOccurrence({
    required this.id,
    required this.scheduleId,
    required this.date,
    required this.transactionId,
  });
  final String id, scheduleId, date, transactionId;
  Map<String, Object?> toJson() => {
    'scheduleId': scheduleId,
    'date': date,
    'transactionId': transactionId,
  };
  factory RecurringOccurrence.fromJson(String id, Map<String, Object?> v) =>
      RecurringOccurrence(
        id: id,
        scheduleId: v['scheduleId'] as String,
        date: v['date'] as String,
        transactionId: v['transactionId'] as String,
      );
}

final class ProcessingResult {
  const ProcessingResult(this.recorded, this.blocked, this.more);
  final int recorded, blocked;
  final bool more;
}

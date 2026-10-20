import '../../../core/domain/money.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';

enum DebtDirection { lent, borrowed }

enum DebtEventKind { principal, payment }

enum DebtStatus { active, overdue, settled }

final class DebtDraft {
  DebtDraft({
    required this.direction,
    required String person,
    required this.principal,
    required this.dueOn,
    String notes = '',
  }) : person = person.trim(),
       notes = notes.trim();
  final DebtDirection direction;
  final String person, dueOn, notes;
  final Money principal;
  void validate() {
    if (person.isEmpty ||
        person.length > 80 ||
        principal.minorUnits <= BigInt.zero ||
        !validTransactionDate(dueOn) ||
        notes.length > 1000) {
      throw const WalletFailure('invalidDebt');
    }
  }

  Map<String, Object?> toJson() => {
    'direction': direction.name,
    'person': person,
    'principal': principal.toJson(),
    'dueOn': dueOn,
    'notes': notes,
  };
  factory DebtDraft.fromJson(Map<String, Object?> v) => DebtDraft(
    direction: DebtDirection.values.byName(v['direction'] as String),
    person: v['person'] as String,
    principal: Money.fromJson(Map<String, Object?>.from(v['principal'] as Map)),
    dueOn: v['dueOn'] as String,
    notes: v['notes'] as String,
  )..validate();
}

final class Debt {
  const Debt({
    required this.id,
    required this.draft,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final DebtDraft draft;
  final int revision;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toJson() => {
    ...draft.toJson(),
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory Debt.fromJson(String id, Map<String, Object?> v) => Debt(
    id: id,
    draft: DebtDraft.fromJson(v),
    revision: v['revision'] as int,
    createdAt: DateTime.parse(v['createdAt'] as String),
    updatedAt: DateTime.parse(v['updatedAt'] as String),
  );
}

final class DebtCashDraft {
  const DebtCashDraft({
    required this.kind,
    required this.walletId,
    required this.amount,
    required this.date,
    this.note = '',
  });
  final DebtEventKind kind;
  final String walletId, date, note;
  final Money amount;
  void validate() {
    if (walletId.isEmpty ||
        amount.minorUnits <= BigInt.zero ||
        !validTransactionDate(date) ||
        note.trim().length > 500) {
      throw const WalletFailure('invalidPayment');
    }
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'walletId': walletId,
    'amount': amount.toJson(),
    'date': date,
    'note': note.trim(),
  };
  factory DebtCashDraft.fromJson(Map<String, Object?> v) => DebtCashDraft(
    kind: DebtEventKind.values.byName(v['kind'] as String),
    walletId: v['walletId'] as String,
    amount: Money.fromJson(Map<String, Object?>.from(v['amount'] as Map)),
    date: v['date'] as String,
    note: v['note'] as String,
  )..validate();
  Money effect(DebtDirection direction) {
    final incoming =
        (direction == DebtDirection.borrowed) ==
        (kind == DebtEventKind.principal);
    return Money(
      incoming ? amount.minorUnits : -amount.minorUnits,
      amount.currency,
    );
  }
}

final class DebtCashEvent {
  const DebtCashEvent({
    required this.id,
    required this.debtId,
    required this.draft,
    required this.revision,
    required this.cancelled,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, debtId;
  final DebtCashDraft draft;
  final int revision;
  final bool cancelled;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toJson() => {
    ...draft.toJson(),
    'debtId': debtId,
    'revision': revision,
    'cancelled': cancelled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory DebtCashEvent.fromJson(String id, Map<String, Object?> v) =>
      DebtCashEvent(
        id: id,
        debtId: v['debtId'] as String,
        draft: DebtCashDraft.fromJson(v),
        revision: v['revision'] as int,
        cancelled: v['cancelled'] as bool,
        createdAt: DateTime.parse(v['createdAt'] as String),
        updatedAt: DateTime.parse(v['updatedAt'] as String),
      );
}

final class DebtSnapshot {
  DebtSnapshot(this.debt, Iterable<DebtCashEvent> events)
    : events = List.unmodifiable(events) {
    if (this.events.any(
          (e) =>
              e.debtId != debt.id ||
              e.draft.amount.currency != debt.draft.principal.currency ||
              (e.draft.kind == DebtEventKind.principal &&
                  e.draft.amount != debt.draft.principal),
        ) ||
        this.events
                .where(
                  (e) =>
                      !e.cancelled && e.draft.kind == DebtEventKind.principal,
                )
                .length >
            1 ||
        paid.minorUnits > debt.draft.principal.minorUnits) {
      throw const WalletFailure('integrity');
    }
  }
  final Debt debt;
  final List<DebtCashEvent> events;
  Money get paid => Money(
    events
        .where((e) => !e.cancelled && e.draft.kind == DebtEventKind.payment)
        .fold(BigInt.zero, (sum, e) => sum + e.draft.amount.minorUnits),
    debt.draft.principal.currency,
  );
  Money get remaining => debt.draft.principal - paid;
  bool get principalRecorded => events.any(
    (e) => !e.cancelled && e.draft.kind == DebtEventKind.principal,
  );
  DebtStatus status(DateTime now) => remaining.minorUnits == BigInt.zero
      ? DebtStatus.settled
      : debt.draft.dueOn.compareTo(calendarDate(now)) < 0
      ? DebtStatus.overdue
      : DebtStatus.active;
  double get progress =>
      (paid.minorUnits * BigInt.from(10000) ~/ debt.draft.principal.minorUnits)
          .toInt() /
      10000;
  bool concealed(Iterable<WalletSnapshot> wallets) => wallets.any(
    (w) =>
        w.wallet.hidden && events.any((e) => e.draft.walletId == w.wallet.id),
  );
}

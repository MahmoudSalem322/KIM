import '../../../core/domain/money.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';

const goalIcons = [
  'savings',
  'home',
  'travel',
  'education',
  'car',
  'heart',
  'gift',
  'shield',
];

final class GoalDraft {
  GoalDraft({
    required String name,
    required this.target,
    required this.dueOn,
    required this.color,
    required this.icon,
  }) : name = name.trim();
  final String name, dueOn, color, icon;
  final Money target;
  void validate() {
    if (name.isEmpty ||
        name.length > 80 ||
        target.minorUnits <= BigInt.zero ||
        !validTransactionDate(dueOn) ||
        !walletColors.contains(color) ||
        !goalIcons.contains(icon)) {
      throw const WalletFailure('invalidGoal');
    }
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'target': target.toJson(),
    'dueOn': dueOn,
    'color': color,
    'icon': icon,
  };
  factory GoalDraft.fromJson(Map<String, Object?> v) => GoalDraft(
    name: v['name'] as String,
    target: Money.fromJson(Map<String, Object?>.from(v['target'] as Map)),
    dueOn: v['dueOn'] as String,
    color: v['color'] as String,
    icon: v['icon'] as String,
  )..validate();
}

final class GoalContribution {
  GoalContribution({
    required this.id,
    required this.goalId,
    required this.walletId,
    required this.delta,
    required this.at,
    required this.note,
    required this.closing,
  });
  final String id, goalId, walletId, note;
  final Money delta;
  final DateTime at;
  final bool closing;
  Map<String, Object?> toJson() => {
    'goalId': goalId,
    'walletId': walletId,
    'delta': delta.toJson(),
    'at': at.toIso8601String(),
    'note': note,
    'closing': closing,
  };
  factory GoalContribution.fromJson(String id, Map<String, Object?> v) =>
      GoalContribution(
        id: id,
        goalId: v['goalId'] as String,
        walletId: v['walletId'] as String,
        delta: Money.fromJson(Map<String, Object?>.from(v['delta'] as Map)),
        at: DateTime.parse(v['at'] as String),
        note: v['note'] as String,
        closing: v['closing'] as bool,
      );
}

final class SavingsGoal {
  SavingsGoal({
    required this.id,
    required this.draft,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.closedAmount,
  });
  final String id;
  final GoalDraft draft;
  final int revision;
  final DateTime createdAt, updatedAt;
  final DateTime? closedAt;
  final Money? closedAmount;
  bool get closed => closedAt != null;
  Map<String, Object?> toJson() => {
    ...draft.toJson(),
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'closedAmount': closedAmount?.toJson(),
  };
  factory SavingsGoal.fromJson(String id, Map<String, Object?> v) =>
      SavingsGoal(
        id: id,
        draft: GoalDraft.fromJson(v),
        revision: v['revision'] as int,
        createdAt: DateTime.parse(v['createdAt'] as String),
        updatedAt: DateTime.parse(v['updatedAt'] as String),
        closedAt: v['closedAt'] == null
            ? null
            : DateTime.parse(v['closedAt'] as String),
        closedAmount: v['closedAmount'] == null
            ? null
            : Money.fromJson(
                Map<String, Object?>.from(v['closedAmount'] as Map),
              ),
      );
}

final class GoalSnapshot {
  GoalSnapshot(this.goal, Iterable<GoalContribution> events)
    : events = List.unmodifiable(events) {
    goal.draft.validate();
    for (final e in this.events) {
      if (e.goalId != goal.id ||
          e.delta.currency != goal.draft.target.currency ||
          e.delta.minorUnits == BigInt.zero) {
        throw const WalletFailure('integrity');
      }
    }
    final releasedOnClosing = this.events
        .where((e) => e.closing)
        .fold(BigInt.zero, (sum, e) => sum - e.delta.minorUnits);
    if ((goal.closed != (goal.closedAmount != null)) ||
        (goal.closedAmount != null &&
            (goal.closedAmount!.currency != goal.draft.target.currency ||
                goal.closedAmount!.minorUnits.isNegative ||
                goal.closedAmount!.minorUnits > goal.draft.target.minorUnits ||
                goal.closedAmount!.minorUnits != releasedOnClosing)) ||
        (!goal.closed && this.events.any((e) => e.closing)) ||
        this.events.any((e) => e.closing && !e.delta.minorUnits.isNegative) ||
        byWallet.values.any((m) => m.minorUnits.isNegative) ||
        allocated.minorUnits > goal.draft.target.minorUnits ||
        (goal.closed &&
            (allocated.minorUnits != BigInt.zero ||
                goal.closedAmount == null))) {
      throw const WalletFailure('integrity');
    }
  }
  final SavingsGoal goal;
  final List<GoalContribution> events;
  Map<String, Money> get byWallet {
    final result = <String, Money>{};
    for (final e in events) {
      result[e.walletId] =
          (result[e.walletId] ?? Money(BigInt.zero, e.delta.currency)) +
          e.delta;
    }
    return result;
  }

  Money get allocated => Money(
    events.fold(BigInt.zero, (sum, e) => sum + e.delta.minorUnits),
    goal.draft.target.currency,
  );
  Money get displayed => goal.closedAmount ?? allocated;
  bool get achieved => displayed.minorUnits >= goal.draft.target.minorUnits;
  Money get remaining => goal.draft.target - displayed;
  String get percentage {
    final tenths =
        displayed.minorUnits *
        BigInt.from(1000) ~/
        goal.draft.target.minorUnits;
    return '${tenths ~/ BigInt.from(10)}.${tenths % BigInt.from(10)}%';
  }

  double get progress =>
      (displayed.minorUnits *
              BigInt.from(10000) ~/
              goal.draft.target.minorUnits)
          .toInt() /
      10000;

  /// UTC calendar dates avoid DST and 23/25-hour local days.
  int daysRemaining(DateTime today) =>
      DateTime.parse('${goal.draft.dueOn}T00:00:00Z')
          .difference(DateTime.utc(today.year, today.month, today.day))
          .inDays;
  bool concealed(Iterable<WalletSnapshot> wallets) => wallets.any(
    (w) => w.wallet.hidden && events.any((e) => e.walletId == w.wallet.id),
  );
}

Money walletReservation(
  String id,
  Currency currency,
  Iterable<GoalSnapshot> goals,
) => Money(
  goals.fold(
    BigInt.zero,
    (sum, g) => sum + (g.byWallet[id]?.minorUnits ?? BigInt.zero),
  ),
  currency,
);

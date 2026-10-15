import '../../../core/domain/money.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';

enum BudgetCycle { weekly, monthly }

final class BudgetPeriod {
  const BudgetPeriod(this.from, this.to);
  final String from, to;
  factory BudgetPeriod.containing(BudgetCycle cycle, DateTime date) {
    final start = cycle == BudgetCycle.monthly
        ? DateTime(date.year, date.month)
        : DateTime(date.year, date.month, date.day - date.weekday + 1);
    final end = cycle == BudgetCycle.monthly
        ? DateTime(date.year, date.month + 1, 0)
        : DateTime(start.year, start.month, start.day + 6);
    return BudgetPeriod(calendarDate(start), calendarDate(end));
  }
  bool contains(String date) =>
      date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
}

final class BudgetDraft {
  BudgetDraft({
    required this.name,
    required this.limit,
    required this.cycle,
    required this.startsOn,
    this.category = '',
    List<int> thresholds = const [50, 80, 100],
  }) : thresholds = List.unmodifiable(thresholds.toSet().toList()..sort());
  final String name, startsOn, category;
  final Money limit;
  final BudgetCycle cycle;
  final List<int> thresholds;
  void validate() {
    if (name.trim().isEmpty ||
        name.trim().length > 80 ||
        limit.minorUnits <= BigInt.zero ||
        !validTransactionDate(startsOn) ||
        BudgetPeriod.containing(cycle, DateTime.parse(startsOn)).from !=
            startsOn ||
        thresholds.any((v) => ![50, 80, 100].contains(v))) {
      throw const WalletFailure('invalidBudget');
    }
  }

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'limit': limit.toJson(),
    'cycle': cycle.name,
    'startsOn': startsOn,
    'category': category,
    'thresholds': thresholds,
  };
}

final class Budget {
  const Budget({
    required this.id,
    required this.draft,
    required this.revision,
    required this.archived,
  });
  final String id;
  final BudgetDraft draft;
  final int revision;
  final bool archived;
  Map<String, Object?> toJson() => {
    ...draft.toJson(),
    'revision': revision,
    'archived': archived,
  };
  factory Budget.fromJson(String id, Map<String, Object?> v) {
    final draft = BudgetDraft(
      name: v['name'] as String,
      limit: Money.fromJson(Map<String, Object?>.from(v['limit'] as Map)),
      cycle: BudgetCycle.values.byName(v['cycle'] as String),
      startsOn: v['startsOn'] as String,
      category: v['category'] as String,
      thresholds: (v['thresholds'] as List).cast<int>(),
    );
    draft.validate();
    return Budget(
      id: id,
      draft: draft,
      revision: v['revision'] as int,
      archived: v['archived'] as bool,
    );
  }
}

final class BudgetUsage {
  BudgetUsage(
    this.budget,
    DateTime date,
    List<FinancialTransaction> transactions,
    List<WalletSnapshot> wallets,
  ) {
    period = BudgetPeriod.containing(budget.draft.cycle, date);
    started = period.from.compareTo(budget.draft.startsOn) >= 0;
    final ids = <String>{};
    final expenses = transactions
        .where(
          (t) =>
              started &&
              !t.deleted &&
              t.draft.kind == TransactionKind.expense &&
              t.draft.amount.currency == budget.draft.limit.currency &&
              period.contains(t.date) &&
              (budget.draft.category.isEmpty ||
                  t.draft.category == budget.draft.category) &&
              ids.add(t.id),
        )
        .toList();
    spent = expenses.fold(
      Money(BigInt.zero, budget.draft.limit.currency),
      (v, t) => v + t.draft.amount,
    );
    remaining = budget.draft.limit - spent;
    final includedIds = expenses.map((t) => t.walletId).toSet();
    concealed = wallets.any(
      (w) =>
          w.wallet.hidden &&
          w.wallet.currency == budget.draft.limit.currency &&
          (!w.wallet.archived || includedIds.contains(w.wallet.id)),
    );
    crossed = started
        ? budget.draft.thresholds
              .where(
                (p) =>
                    spent.minorUnits * BigInt.from(100) >=
                    budget.draft.limit.minorUnits * BigInt.from(p),
              )
              .lastOrNull
        : null;
  }
  final Budget budget;
  late final BudgetPeriod period;
  late final Money spent, remaining;
  late final bool started, concealed;
  late final int? crossed;
  String get percentage {
    final tenths =
        spent.minorUnits * BigInt.from(1000) ~/ budget.draft.limit.minorUnits;
    return '${tenths ~/ BigInt.from(10)}.${tenths % BigInt.from(10)}%';
  }

  double get progress {
    final scaled =
        spent.minorUnits *
        BigInt.from(1000000) ~/
        budget.draft.limit.minorUnits;
    return scaled >= BigInt.from(1000000) ? 1 : scaled.toInt() / 1000000;
  }
}

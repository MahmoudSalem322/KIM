import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/savings_reservations.dart';
import '../../../core/domain/money.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/savings_goal.dart';
import '../domain/savings_repository.dart';

final class LocalSavingsRepository implements SavingsRepository {
  LocalSavingsRepository(this.db);
  final AppDatabase db;
  Future<List<GoalSnapshot>> _read(DatabaseClient txn) async {
    final events =
        (await savingsEventsStore.find(txn))
            .map((r) => GoalContribution.fromJson(r.key, r.value))
            .toList()
          ..sort((a, b) {
            final d = b.at.compareTo(a.at);
            return d != 0 ? d : b.id.compareTo(a.id);
          });
    final goals =
        (await savingsGoalsStore.find(txn))
            .map((r) => SavingsGoal.fromJson(r.key, r.value))
            .toList()
          ..sort((a, b) {
            final d = b.createdAt.compareTo(a.createdAt);
            return d != 0 ? d : b.id.compareTo(a.id);
          });
    if (events.any((e) => !goals.any((g) => g.id == e.goalId))) {
      throw const WalletFailure('integrity');
    }
    final result = [
      for (final g in goals)
        GoalSnapshot(g, events.where((e) => e.goalId == g.id)),
    ];
    final ids = events.map((e) => e.walletId).toSet();
    for (final id in ids) {
      final w = await savingsWallet(txn, id);
      for (final e in events.where((e) => e.walletId == id)) {
        if (e.delta.currency != w.wallet.currency) {
          throw const WalletFailure('integrity');
        }
      }
    }
    await protectSavings(txn, ids);
    return List.unmodifiable(result);
  }

  @override
  Future<List<GoalSnapshot>> load() => db.database.transaction(_read);
  @override
  Stream<List<GoalSnapshot>> watch() => savingsGoalsStore
      .query()
      .onSnapshots(db.database)
      .asyncMap((_) => load());
  Future<GoalSnapshot> _current(
    Transaction txn,
    String id,
    int revision,
  ) async {
    final value = await savingsGoalsStore.record(id).get(txn);
    if (value == null) throw const WalletFailure('notFound');
    final g = SavingsGoal.fromJson(id, value);
    if (g.revision != revision) throw const WalletFailure('conflict');
    if (g.closed) throw const WalletFailure('closedGoal');
    final rows = await savingsEventsStore.find(
      txn,
      finder: Finder(filter: Filter.equals('goalId', id)),
    );
    return GoalSnapshot(
      g,
      rows.map((r) => GoalContribution.fromJson(r.key, r.value)),
    );
  }

  Future<void> _write(
    WalletOperation op,
    String type,
    List<Object?> args,
    Future<void> Function(Transaction) run,
  ) => db
      .applyOnce(
        op.id,
        jsonEncode(['savings-v1', type, op.at.toIso8601String(), ...args]),
        run,
      )
      .then((_) {});
  Future<void> _touch(
    Transaction txn,
    SavingsGoal g,
    WalletOperation op, {
    GoalDraft? draft,
    Money? closedAmount,
  }) async {
    await savingsGoalsStore.record(g.id).put(txn, {
      ...g.toJson(),
      if (draft != null) ...draft.toJson(),
      'revision': g.revision + 1,
      'updatedAt': op.at.toIso8601String(),
      if (closedAmount != null) ...{
        'closedAt': op.at.toIso8601String(),
        'closedAmount': closedAmount.toJson(),
      },
    });
  }

  Future<void> _event(
    Transaction txn,
    WalletOperation op,
    String goalId,
    String walletId,
    Money delta,
    String note, {
    bool closing = false,
  }) async {
    final id = const Uuid().v5(op.id.value, walletId);
    if (await savingsEventsStore.record(id).exists(txn)) {
      throw const WalletFailure('conflict');
    }
    await savingsEventsStore
        .record(id)
        .put(
          txn,
          GoalContribution(
            id: id,
            goalId: goalId,
            walletId: walletId,
            delta: delta,
            at: op.at,
            note: note,
            closing: closing,
          ).toJson(),
        );
    // A reservation changes spendable funds, but never the financial ledger.
    final store = stringMapStoreFactory.store('wallets');
    final value = (await store.record(walletId).get(txn))!;
    await store.record(walletId).put(txn, {
      ...value,
      'revision': (value['revision'] as int) + 1,
      'updatedAt': op.at.toIso8601String(),
    });
  }

  @override
  Future<String> create(WalletOperation op, GoalDraft draft) async {
    draft.validate();
    await _write(op, 'create', [draft.toJson()], (txn) async {
      if (await savingsGoalsStore.record(op.id.value).exists(txn)) {
        throw const WalletFailure('conflict');
      }
      await savingsGoalsStore
          .record(op.id.value)
          .put(
            txn,
            SavingsGoal(
              id: op.id.value,
              draft: draft,
              revision: 0,
              createdAt: op.at,
              updatedAt: op.at,
            ).toJson(),
          );
    });
    return op.id.value;
  }

  @override
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    GoalDraft draft,
  ) async {
    draft.validate();
    await _write(op, 'edit', [id, revision, draft.toJson()], (txn) async {
      final s = await _current(txn, id, revision);
      if (draft.target.currency != s.goal.draft.target.currency) {
        throw const WalletFailure('currency');
      }
      if (draft.target.minorUnits < s.allocated.minorUnits) {
        throw const WalletFailure('belowAllocated');
      }
      await _touch(txn, s.goal, op, draft: draft);
    });
  }

  @override
  Future<void> allocate(
    WalletOperation op,
    String id,
    int revision,
    String walletId,
    int walletRevision,
    Money amount,
    String note,
  ) async {
    if (amount.minorUnits.isNegative || note.trim().length > 500) {
      throw const WalletFailure('invalidAllocation');
    }
    await _write(
      op,
      'allocate',
      [id, revision, walletId, walletRevision, amount.toJson(), note.trim()],
      (txn) async {
        final s = await _current(txn, id, revision),
            w = await savingsWallet(txn, walletId);
        if (w.wallet.revision != walletRevision) {
          throw const WalletFailure('conflict');
        }
        if (w.wallet.archived) throw const WalletFailure('archived');
        if (amount.currency != s.goal.draft.target.currency ||
            amount.currency != w.wallet.currency) {
          throw const WalletFailure('currency');
        }
        final previous =
                s.byWallet[walletId] ?? Money(BigInt.zero, amount.currency),
            delta = amount - previous;
        if (delta.minorUnits == BigInt.zero) {
          throw const WalletFailure('noChange');
        }
        if ((s.allocated + delta).minorUnits > s.goal.draft.target.minorUnits) {
          throw const WalletFailure('aboveTarget');
        }
        await _event(txn, op, id, walletId, delta, note.trim());
        await protectSavings(txn, [walletId]);
        await _touch(txn, s.goal, op);
      },
    );
  }

  @override
  Future<void> close(WalletOperation op, String id, int revision) =>
      _write(op, 'close', [id, revision], (txn) async {
        final s = await _current(txn, id, revision);
        for (final e in s.byWallet.entries) {
          if (e.value.minorUnits > BigInt.zero) {
            await _event(
              txn,
              op,
              id,
              e.key,
              Money(-e.value.minorUnits, e.value.currency),
              '',
              closing: true,
            );
          }
        }
        await _touch(txn, s.goal, op, closedAmount: s.allocated);
      });
}

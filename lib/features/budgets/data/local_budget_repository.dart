import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../../../core/data/app_database.dart';
import '../../categories/data/local_category_repository.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/budget.dart';
import '../domain/budget_repository.dart';

final class LocalBudgetRepository implements BudgetRepository {
  LocalBudgetRepository(this.db);
  final AppDatabase db;
  static final store = stringMapStoreFactory.store('budgets');
  @override
  Future<List<Budget>> load() => db.database.transaction((txn) async {
    final result = (await store.find(txn))
        .map((r) => Budget.fromJson(r.key, r.value))
        .toList();
    for (final b in result) {
      if (b.draft.category.isNotEmpty) {
        await LocalCategoryRepository.requireAssignable(
          txn,
          b.draft.category,
          TransactionKind.expense,
          allowArchived: true,
        );
      }
    }
    return List.unmodifiable(result);
  });
  @override
  Stream<List<Budget>> watch() =>
      store.query().onSnapshots(db.database).asyncMap((_) => load());
  Future<Budget> _current(Transaction txn, String id, int revision) async {
    final v = await store.record(id).get(txn);
    if (v == null) throw const WalletFailure('notFound');
    final b = Budget.fromJson(id, v);
    if (b.revision != revision) throw const WalletFailure('conflict');
    return b;
  }

  Future<void> _validate(
    Transaction txn,
    BudgetDraft d,
    String id, {
    String? retainedCategory,
  }) async {
    d.validate();
    if (d.category.isNotEmpty) {
      await LocalCategoryRepository.requireAssignable(
        txn,
        d.category,
        TransactionKind.expense,
        allowArchived: retainedCategory == d.category,
      );
    }
    for (final row in await store.find(txn)) {
      if (row.key == id) continue;
      final other = Budget.fromJson(row.key, row.value);
      if (!other.archived &&
          other.draft.cycle == d.cycle &&
          other.draft.category == d.category &&
          other.draft.limit.currency == d.limit.currency) {
        throw const WalletFailure('duplicateBudget');
      }
    }
  }

  Future<void> _write(
    WalletOperation op,
    String type,
    List<Object?> args,
    Future<void> Function(Transaction) run,
  ) => db
      .applyOnce(
        op.id,
        jsonEncode(['budget-v1', type, op.at.toIso8601String(), ...args]),
        run,
      )
      .then((_) {});
  @override
  Future<String> create(WalletOperation op, BudgetDraft draft) async {
    draft.validate();
    final id = op.id.value;
    await _write(op, 'create', [draft.toJson()], (txn) async {
      if (await store.record(id).exists(txn)) {
        throw const WalletFailure('conflict');
      }
      await _validate(txn, draft, id);
      await store
          .record(id)
          .put(
            txn,
            Budget(id: id, draft: draft, revision: 0, archived: false).toJson(),
          );
    });
    return id;
  }

  @override
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    BudgetDraft draft,
  ) => _write(op, 'edit', [id, revision, draft.toJson()], (txn) async {
    final b = await _current(txn, id, revision);
    await _validate(txn, draft, id, retainedCategory: b.draft.category);
    await store
        .record(id)
        .put(
          txn,
          Budget(
            id: id,
            draft: draft,
            revision: revision + 1,
            archived: b.archived,
          ).toJson(),
        );
  });
  @override
  Future<void> setArchived(
    WalletOperation op,
    String id,
    int revision,
    bool archived,
  ) => _write(op, 'archive', [id, revision, archived], (txn) async {
    final b = await _current(txn, id, revision);
    if (!archived) {
      await _validate(txn, b.draft, id, retainedCategory: b.draft.category);
    }
    await store.record(id).put(txn, {
      ...b.toJson(),
      'archived': archived,
      'revision': revision + 1,
    });
  });
  @override
  Future<void> delete(WalletOperation op, String id, int revision) =>
      _write(op, 'delete', [id, revision], (txn) async {
        await _current(txn, id, revision);
        await store.record(id).delete(txn);
      });
}

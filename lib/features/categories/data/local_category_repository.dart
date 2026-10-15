import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../../../core/data/app_database.dart';
import '../../wallets/domain/wallet.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../domain/app_category.dart';
import '../domain/category_repository.dart';
import 'category_schema.dart';

final class LocalCategoryRepository implements CategoryRepository {
  LocalCategoryRepository(this.db);
  final AppDatabase db;
  @override
  Future<List<AppCategory>> load() async {
    final rows = await categoryStore.find(db.database);
    final categories = rows
        .map((r) => AppCategory.fromJson(r.key, r.value))
        .toList();
    categories.sort((a, b) {
      final kind = a.draft.kind.index.compareTo(b.draft.kind.index);
      if (kind != 0) return kind;
      return a.id.compareTo(b.id);
    });
    return List.unmodifiable(categories);
  }

  @override
  Stream<List<AppCategory>> watch() =>
      categoryStore.query().onSnapshots(db.database).asyncMap((_) => load());

  static Future<void> requireAssignable(
    Transaction txn,
    String id,
    TransactionKind kind, {
    bool allowArchived = false,
  }) async {
    final value = await categoryStore.record(id).get(txn);
    if (value == null) throw const WalletFailure('category');
    final c = AppCategory.fromJson(id, value);
    if (c.draft.kind != kind || (!allowArchived && c.archived)) {
      throw const WalletFailure('category');
    }
  }

  Future<AppCategory> _current(Transaction txn, String id, int revision) async {
    final value = await categoryStore.record(id).get(txn);
    if (value == null) throw const WalletFailure('notFound');
    final c = AppCategory.fromJson(id, value);
    if (c.revision != revision) throw const WalletFailure('conflict');
    return c;
  }

  Future<void> _unique(Transaction txn, CategoryDraft draft, String id) async {
    final rows = await categoryStore.find(txn);
    if (rows.any(
      (r) =>
          r.key != id &&
          r.value['kind'] == draft.kind.name &&
          (r.value['name'] as String).trim().toLowerCase() ==
              draft.name.trim().toLowerCase() &&
          draft.name.trim().isNotEmpty,
    )) {
      throw const WalletFailure('duplicateCategory');
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
        jsonEncode(['category-v1', type, op.at.toIso8601String(), ...args]),
        run,
      )
      .then((_) {});
  @override
  Future<String> create(WalletOperation op, CategoryDraft draft) async {
    draft.validate();
    final id = op.id.value;
    await _write(op, 'create', [draft.toJson()], (txn) async {
      if (await categoryStore.record(id).exists(txn)) {
        throw const WalletFailure('conflict');
      }
      await _unique(txn, draft, id);
      await categoryStore
          .record(id)
          .put(
            txn,
            AppCategory(
              id: id,
              draft: draft,
              revision: 0,
              archived: false,
              builtin: false,
            ).toJson(),
          );
    });
    return id;
  }

  @override
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    CategoryDraft draft,
  ) => _write(op, 'edit', [id, revision, draft.toJson()], (txn) async {
    final c = await _current(txn, id, revision);
    draft.validate(builtin: c.builtin);
    if (c.draft.kind != draft.kind) throw const WalletFailure('category');
    await _unique(txn, draft, id);
    await categoryStore
        .record(id)
        .put(
          txn,
          AppCategory(
            id: id,
            draft: draft,
            revision: revision + 1,
            archived: c.archived,
            builtin: c.builtin,
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
    final c = await _current(txn, id, revision);
    if (id == 'transferFee') throw const WalletFailure('reservedCategory');
    await categoryStore.record(id).put(txn, {
      ...c.toJson(),
      'revision': revision + 1,
      'archived': archived,
    });
  });
  @override
  Future<void> delete(WalletOperation op, String id, int revision) =>
      _write(op, 'delete', [id, revision], (txn) async {
        final c = await _current(txn, id, revision);
        if (c.builtin) throw const WalletFailure('reservedCategory');
        for (final store in [
          stringMapStoreFactory.store('transactions'),
          stringMapStoreFactory.store('budgets'),
        ]) {
          if ((await store.find(
            txn,
            finder: Finder(filter: Filter.equals('category', id), limit: 1),
          )).isNotEmpty) {
            throw const WalletFailure('categoryInUse');
          }
        }
        await categoryStore.record(id).delete(txn);
      });
}

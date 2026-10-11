import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../../../core/data/app_database.dart';
import '../../../core/domain/money.dart';
import '../domain/wallet.dart';
import '../domain/wallet_repository.dart';

final class LocalWalletRepository implements WalletRepository {
  LocalWalletRepository(this.db);
  final AppDatabase db;
  static final wallets = stringMapStoreFactory.store('wallets');
  static final entries = stringMapStoreFactory.store('wallet_entries');

  @override
  Future<List<WalletSnapshot>> load() => db.database.transaction(_read);
  Future<List<WalletSnapshot>> _read(DatabaseClient client) async {
    final metadata = await wallets.find(client);
    final ledger = await entries.find(client);
    final grouped = <String, List<WalletEntry>>{};
    for (final row in ledger) {
      final entry = WalletEntry.fromJson(row.key, row.value);
      (grouped[entry.walletId] ??= []).add(entry);
    }
    final result = metadata.map((row) {
      final w = Wallet.fromJson(row.key, row.value);
      final history = grouped[w.id] ?? [];
      history.sort((a, b) => a.sequence.compareTo(b.sequence));
      return WalletSnapshot(w, history);
    }).toList();
    result.sort((a, b) {
      final order = a.wallet.position.compareTo(b.wallet.position);
      return order != 0 ? order : a.wallet.id.compareTo(b.wallet.id);
    });
    return List.unmodifiable(result);
  }

  @override
  Stream<List<WalletSnapshot>> watch() =>
      wallets.query().onSnapshots(db.database).asyncMap((_) => load());

  String _request(String type, WalletOperation op, List<Object?> args) =>
      jsonEncode(['wallet-v1', type, op.at.toIso8601String(), ...args]);
  Future<Map<String, Object?>> _current(
    Transaction txn,
    String id,
    int revision, {
    bool allowArchived = false,
  }) async {
    final value = await wallets.record(id).get(txn);
    if (value == null) throw const WalletFailure('notFound');
    if (value['revision'] != revision) throw const WalletFailure('conflict');
    if (!allowArchived && value['archived'] == true)
      throw const WalletFailure('archived');
    return Map.of(value);
  }

  Future<void> _update(
    Transaction txn,
    String id,
    Map<String, Object?> value,
    WalletOperation op,
  ) async {
    value['revision'] = (value['revision'] as int) + 1;
    value['updatedAt'] = op.at.toIso8601String();
    await wallets.record(id).put(txn, value);
  }

  @override
  Future<String> create(
    WalletOperation op,
    WalletDraft draft,
    Money opening,
  ) async {
    draft.validate();
    if (opening.currency != draft.currency)
      throw const WalletFailure('currency');
    final id = op.id.value;
    await db.applyOnce(
      op.id,
      _request('create', op, [draft.toJson(), opening.toJson()]),
      (txn) async {
        if (await wallets.record(id).exists(txn))
          throw const WalletFailure('conflict');
        final active = await wallets.find(
          txn,
          finder: Finder(filter: Filter.equals('archived', false)),
        );
        final next =
            active.fold(
              -1,
              (int m, r) => (r.value['position'] as int) > m
                  ? r.value['position'] as int
                  : m,
            ) +
            1;
        await wallets.record(id).put(txn, {
          ...draft.toJson(),
          'revision': 0,
          'position': next,
          'archived': false,
          'hidden': false,
          'createdAt': op.at.toIso8601String(),
          'updatedAt': op.at.toIso8601String(),
        });
        final zero = Money(BigInt.zero, draft.currency);
        await entries
            .record(id)
            .put(
              txn,
              WalletEntry(
                operationId: id,
                walletId: id,
                kind: WalletEntryKind.opening,
                delta: opening,
                before: zero,
                after: opening,
                at: op.at,
                reason: '',
                sequence: 0,
              ).toJson(),
            );
      },
    );
    return id;
  }

  @override
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    WalletDraft draft,
  ) async {
    draft.validate();
    await db.applyOnce(
      op.id,
      _request('edit', op, [id, revision, draft.toJson()]),
      (txn) async {
        final value = await _current(txn, id, revision);
        if (Currency(value['currency'] as String, value['scale'] as int) !=
            draft.currency) {
          throw const WalletFailure('currency');
        }
        value.addAll(draft.toJson());
        await _update(txn, id, value, op);
      },
    );
  }

  @override
  Future<void> adjust(
    WalletOperation op,
    String id,
    int revision,
    Money target,
    String reason,
  ) async {
    if (reason.trim().isEmpty || reason.trim().length > 500)
      throw const WalletFailure('reason');
    await db.applyOnce(
      op.id,
      _request('adjust', op, [id, revision, target.toJson(), reason.trim()]),
      (txn) async {
        final value = await _current(txn, id, revision);
        final currency = Currency(
          value['currency'] as String,
          value['scale'] as int,
        );
        if (target.currency != currency) throw const WalletFailure('currency');
        final history = await entries.find(
          txn,
          finder: Finder(filter: Filter.equals('walletId', id)),
        );
        final before = history.fold(
          Money(BigInt.zero, currency),
          (total, r) => total + WalletEntry.fromJson(r.key, r.value).delta,
        );
        final delta = target - before;
        if (delta.minorUnits == BigInt.zero)
          throw const WalletFailure('noChange');
        await entries
            .record(op.id.value)
            .put(
              txn,
              WalletEntry(
                operationId: op.id.value,
                walletId: id,
                kind: WalletEntryKind.adjustment,
                delta: delta,
                before: before,
                after: target,
                at: op.at,
                reason: reason.trim(),
                sequence: revision + 1,
              ).toJson(),
            );
        await _update(txn, id, value, op);
      },
    );
  }

  @override
  Future<void> setHidden(
    WalletOperation op,
    String id,
    int revision,
    bool hidden,
  ) async {
    await db.applyOnce(op.id, _request('hide', op, [id, revision, hidden]), (
      txn,
    ) async {
      final value = await _current(txn, id, revision, allowArchived: true);
      value['hidden'] = hidden;
      await _update(txn, id, value, op);
    });
  }

  @override
  Future<void> setArchived(
    WalletOperation op,
    String id,
    int revision,
    bool archived,
  ) async {
    await db.applyOnce(
      op.id,
      _request('archive', op, [id, revision, archived]),
      (txn) async {
        final value = await _current(txn, id, revision, allowArchived: true);
        if (value['archived'] == archived)
          throw const WalletFailure('noChange');
        if (!archived) {
          final active = await wallets.find(
            txn,
            finder: Finder(filter: Filter.equals('archived', false)),
          );
          value['position'] =
              active.fold(
                -1,
                (int m, r) => (r.value['position'] as int) > m
                    ? r.value['position'] as int
                    : m,
              ) +
              1;
        }
        value['archived'] = archived;
        await _update(txn, id, value, op);
      },
    );
  }

  @override
  Future<void> reorder(
    WalletOperation op,
    List<String> ids,
    Map<String, int> revisions,
  ) async {
    final expected = ids.map((id) => [id, revisions[id]]).toList();
    await db.applyOnce(op.id, _request('reorder', op, [expected]), (txn) async {
      final active = await wallets.find(
        txn,
        finder: Finder(filter: Filter.equals('archived', false)),
      );
      if (ids.length != ids.toSet().length ||
          ids.length != active.length ||
          active.any((r) => !ids.contains(r.key)))
        throw const WalletFailure('conflict');
      final byId = {
        for (final r in active) r.key: Map<String, Object?>.of(r.value),
      };
      for (final id in ids) {
        if (byId[id]!['revision'] != revisions[id])
          throw const WalletFailure('conflict');
      }
      for (var i = 0; i < ids.length; i++) {
        final value = byId[ids[i]]!;
        if (value['position'] != i) {
          value['position'] = i;
          await _update(txn, ids[i], value, op);
        }
      }
    });
  }
}

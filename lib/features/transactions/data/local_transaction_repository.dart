import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../../../core/domain/money.dart';
import '../../wallets/data/local_wallet_repository.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/financial_transaction.dart';
import '../domain/transaction_repository.dart';

final class LocalTransactionRepository implements TransactionRepository {
  LocalTransactionRepository(this.db);
  final AppDatabase db;
  static final store = stringMapStoreFactory.store('transactions');
  @override
  Future<List<FinancialTransaction>> load() =>
      db.database.transaction((client) async {
        final rows = await store.find(client);
        final result = rows
            .map((r) => FinancialTransaction.fromJson(r.key, r.value))
            .toList();
        final ledger = await LocalWalletRepository.entries.find(client);
        final grouped = <String, List<WalletEntry>>{};
        for (final row in ledger) {
          final entry = WalletEntry.fromJson(row.key, row.value);
          if (entry.transactionId.isNotEmpty) {
            (grouped[entry.transactionId] ??= []).add(entry);
          }
        }
        for (final t in result) {
          _assertEffect(t, grouped[t.id] ?? []);
        }
        result.sort((a, b) {
          final date = b.date.compareTo(a.date);
          if (date != 0) return date;
          final created = b.createdAt.compareTo(a.createdAt);
          return created != 0 ? created : b.id.compareTo(a.id);
        });
        return List.unmodifiable(result);
      });

  void _assertEffect(
    FinancialTransaction current,
    Iterable<WalletEntry> entries,
  ) {
    final net = <String, Money>{};
    if (entries.isEmpty) throw const WalletFailure('integrity');
    for (final entry in entries) {
      if (entry.kind != WalletEntryKind.income &&
          entry.kind != WalletEntryKind.expense &&
          entry.kind != WalletEntryKind.reversal) {
        throw const WalletFailure('integrity');
      }
      final previous = net[entry.walletId];
      if (previous != null && previous.currency != entry.delta.currency) {
        throw const WalletFailure('integrity');
      }
      net[entry.walletId] = previous == null
          ? entry.delta
          : previous + entry.delta;
    }
    final expected = current.deleted
        ? Money(BigInt.zero, current.draft.amount.currency)
        : current.draft.effect;
    if (net[current.walletId] != expected ||
        net.entries.any(
          (e) => e.key != current.walletId && e.value.minorUnits != BigInt.zero,
        )) {
      throw const WalletFailure('integrity');
    }
  }

  @override
  Stream<List<FinancialTransaction>> watch() =>
      store.query().onSnapshots(db.database).asyncMap((_) => load());
  String request(
    String type,
    WalletOperation op,
    List<Object?> args,
    Map<String, int> revisions,
  ) {
    final keys = revisions.keys.toList()..sort();
    return jsonEncode([
      'transaction-v1',
      type,
      op.at.toIso8601String(),
      ...args,
      [
        for (final id in keys) [id, revisions[id]],
      ],
    ]);
  }

  Future<WalletSnapshot> _wallet(
    Transaction txn,
    String id,
    Map<String, int> revisions,
  ) async {
    final metadata = await LocalWalletRepository.wallets.record(id).get(txn);
    if (metadata == null) throw const WalletFailure('notFound');
    final w = Wallet.fromJson(id, metadata);
    if (w.revision != revisions[id]) throw const WalletFailure('conflict');
    if (w.archived) throw const WalletFailure('archived');
    final rows = await LocalWalletRepository.entries.find(
      txn,
      finder: Finder(filter: Filter.equals('walletId', id)),
    );
    final entries =
        rows.map((r) => WalletEntry.fromJson(r.key, r.value)).toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return WalletSnapshot(w, entries);
  }

  Future<void> _append(
    Transaction txn,
    WalletOperation op,
    String entryId,
    String transactionId,
    WalletSnapshot wallet,
    Money delta,
    WalletEntryKind kind,
    String reason,
  ) async {
    if (wallet.wallet.currency != delta.currency) {
      throw const WalletFailure('currency');
    }
    if (await LocalWalletRepository.entries.record(entryId).exists(txn)) {
      throw const WalletFailure('conflict');
    }
    final w = wallet.wallet;
    await LocalWalletRepository.entries
        .record(entryId)
        .put(
          txn,
          WalletEntry(
            operationId: entryId,
            walletId: w.id,
            kind: kind,
            delta: delta,
            before: wallet.balance,
            after: wallet.balance + delta,
            at: op.at,
            reason: reason,
            sequence: w.revision + 1,
            transactionId: transactionId,
          ).toJson(),
        );
    final metadata = (await LocalWalletRepository.wallets
        .record(w.id)
        .get(txn))!;
    await LocalWalletRepository.wallets.record(w.id).put(txn, {
      ...metadata,
      'revision': w.revision + 1,
      'updatedAt': op.at.toIso8601String(),
    });
  }

  Future<FinancialTransaction> _current(
    Transaction txn,
    String id,
    int revision,
  ) async {
    final value = await store.record(id).get(txn);
    if (value == null) throw const WalletFailure('notFound');
    final current = FinancialTransaction.fromJson(id, value);
    if (current.linkedTransferId.isNotEmpty) {
      throw const WalletFailure('linkedTransfer');
    }
    if (current.revision != revision) throw const WalletFailure('conflict');
    if (current.deleted) throw const WalletFailure('deleted');
    final ledger = await LocalWalletRepository.entries.find(
      txn,
      finder: Finder(filter: Filter.equals('transactionId', id)),
    );
    _assertEffect(
      current,
      ledger.map((r) => WalletEntry.fromJson(r.key, r.value)),
    );
    return current;
  }

  WalletEntryKind _kind(TransactionDraft draft) =>
      draft.kind == TransactionKind.income
      ? WalletEntryKind.income
      : WalletEntryKind.expense;
  @override
  Future<String> create(
    WalletOperation op,
    TransactionDraft draft,
    Map<String, int> walletRevisions,
  ) async {
    draft.validate();
    final revisions = Map<String, int>.unmodifiable(walletRevisions);
    final id = op.id.value;
    await db.applyOnce(
      op.id,
      request('create', op, [draft.toJson()], revisions),
      (txn) async {
        if (await store.record(id).exists(txn)) {
          throw const WalletFailure('conflict');
        }
        final wallet = await _wallet(txn, draft.walletId, revisions);
        await _append(
          txn,
          op,
          id,
          id,
          wallet,
          draft.effect,
          _kind(draft),
          draft.category,
        );
        await store.record(id).put(txn, {
          ...draft.toJson(),
          'revision': 0,
          'deleted': false,
          'createdAt': op.at.toIso8601String(),
          'updatedAt': op.at.toIso8601String(),
        });
      },
    );
    return id;
  }

  @override
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    TransactionDraft draft,
    Map<String, int> walletRevisions,
  ) async {
    draft.validate();
    final revisions = Map<String, int>.unmodifiable(walletRevisions);
    final reversalId = const Uuid().v5(op.id.value, 'reversal');
    await db.applyOnce(
      op.id,
      request('edit', op, [id, revision, draft.toJson()], revisions),
      (txn) async {
        final current = await _current(txn, id, revision);
        final oldWallet = await _wallet(txn, current.walletId, revisions);
        // Validate the destination before writing; all failures roll back anyway.
        await _wallet(txn, draft.walletId, revisions);
        await _append(
          txn,
          op,
          reversalId,
          id,
          oldWallet,
          Money(
            -current.draft.effect.minorUnits,
            current.draft.amount.currency,
          ),
          WalletEntryKind.reversal,
          'edit',
        );
        final latestRevisions = {
          ...revisions,
          if (current.walletId == draft.walletId)
            draft.walletId: oldWallet.wallet.revision + 1,
        };
        final newWallet = await _wallet(txn, draft.walletId, latestRevisions);
        await _append(
          txn,
          op,
          op.id.value,
          id,
          newWallet,
          draft.effect,
          _kind(draft),
          draft.category,
        );
        await store.record(id).put(txn, {
          ...draft.toJson(),
          'revision': revision + 1,
          'deleted': false,
          'createdAt': current.createdAt.toIso8601String(),
          'updatedAt': op.at.toIso8601String(),
        });
      },
    );
  }

  @override
  Future<void> delete(
    WalletOperation op,
    String id,
    int revision,
    Map<String, int> walletRevisions,
  ) async {
    final revisions = Map<String, int>.unmodifiable(walletRevisions);
    await db.applyOnce(
      op.id,
      request('delete', op, [id, revision], revisions),
      (txn) async {
        final current = await _current(txn, id, revision);
        final wallet = await _wallet(txn, current.walletId, revisions);
        await _append(
          txn,
          op,
          op.id.value,
          id,
          wallet,
          Money(
            -current.draft.effect.minorUnits,
            current.draft.amount.currency,
          ),
          WalletEntryKind.reversal,
          'cancel',
        );
        final value = (await store.record(id).get(txn))!;
        await store.record(id).put(txn, {
          ...value,
          'revision': revision + 1,
          'deleted': true,
          'updatedAt': op.at.toIso8601String(),
        });
      },
    );
  }
}

import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/savings_reservations.dart';
import '../../../core/domain/money.dart';
import '../../wallets/data/local_wallet_repository.dart';
import '../../wallets/domain/wallet.dart';
import '../../transactions/data/local_transaction_repository.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../domain/wallet_transfer.dart';
import '../domain/transfer_repository.dart';

final class LocalTransferRepository implements TransferRepository {
  LocalTransferRepository(this.db);
  final AppDatabase db;
  static final store = stringMapStoreFactory.store('transfers');
  static String feeId(String id) => const Uuid().v5(id, 'fee');
  Money _negative(Money m) => Money(-m.minorUnits, m.currency);

  @override
  Future<List<WalletTransfer>> load() => db.database.transaction((txn) async {
    final rows = await store.find(txn);
    final result = <WalletTransfer>[];
    for (final row in rows) {
      final current = WalletTransfer.fromJson(row.key, row.value);
      await _assertEffect(txn, current);
      result.add(current);
    }
    result.sort((a, b) {
      final date = b.createdAt.compareTo(a.createdAt);
      return date != 0 ? date : b.id.compareTo(a.id);
    });
    return List.unmodifiable(result);
  });
  @override
  Stream<List<WalletTransfer>> watch() =>
      store.query().onSnapshots(db.database).asyncMap((_) => load());

  Future<void> _assertEffect(Transaction txn, WalletTransfer t) async {
    final rows = await LocalWalletRepository.entries.find(
      txn,
      finder: Finder(filter: Filter.equals('transferId', t.id)),
    );
    if (rows.isEmpty) throw const WalletFailure('integrity');
    final net = <String, Money>{}, fees = <String, Money>{};
    for (final row in rows) {
      final e = WalletEntry.fromJson(row.key, row.value);
      if (e.transactionId.isNotEmpty) {
        if (e.transactionId != feeId(t.id) ||
            (e.kind != WalletEntryKind.expense &&
                e.kind != WalletEntryKind.reversal)) {
          throw const WalletFailure('integrity');
        }
        fees[e.walletId] =
            (fees[e.walletId] ?? Money(BigInt.zero, e.delta.currency)) +
            e.delta;
      } else if (e.kind != WalletEntryKind.transferOut &&
          e.kind != WalletEntryKind.transferIn &&
          e.kind != WalletEntryKind.transferReversal) {
        throw const WalletFailure('integrity');
      }
      net[e.walletId] =
          (net[e.walletId] ?? Money(BigInt.zero, e.delta.currency)) + e.delta;
    }
    final expected = <String, Money>{
      t.draft.sourceId: t.cancelled
          ? Money(BigInt.zero, t.draft.amount.currency)
          : _negative(t.draft.amount + t.draft.fee),
      t.draft.destinationId: t.cancelled
          ? Money(BigInt.zero, t.received.currency)
          : t.received,
    };
    for (final e in expected.entries) {
      if (net[e.key] != e.value) throw const WalletFailure('integrity');
    }
    if (net.entries.any(
      (e) => !expected.containsKey(e.key) && e.value.minorUnits != BigInt.zero,
    )) {
      throw const WalletFailure('integrity');
    }
    final metadata = await LocalTransactionRepository.store
        .record(feeId(t.id))
        .get(txn);
    final activeFee = !t.cancelled && t.draft.fee.minorUnits > BigInt.zero;
    if (metadata == null) {
      if (activeFee || fees.isNotEmpty) throw const WalletFailure('integrity');
    } else {
      final fee = FinancialTransaction.fromJson(feeId(t.id), metadata);
      if (fee.linkedTransferId != t.id ||
          fee.draft.kind != TransactionKind.expense ||
          fee.draft.category != 'transferFee' ||
          fee.deleted == activeFee) {
        throw const WalletFailure('integrity');
      }
      final expectedFee = activeFee
          ? _negative(t.draft.fee)
          : Money(BigInt.zero, fee.draft.amount.currency);
      if (activeFee &&
          (fee.walletId != t.draft.sourceId ||
              fee.draft.amount != t.draft.fee)) {
        throw const WalletFailure('integrity');
      }
      if (fees[fee.walletId] != expectedFee ||
          fees.entries.any(
            (e) => e.key != fee.walletId && e.value.minorUnits != BigInt.zero,
          )) {
        throw const WalletFailure('integrity');
      }
    }
  }

  Future<WalletSnapshot> _wallet(
    Transaction txn,
    String id, {
    int? revision,
  }) async {
    final value = await LocalWalletRepository.wallets.record(id).get(txn);
    if (value == null) throw const WalletFailure('notFound');
    final wallet = Wallet.fromJson(id, value);
    if (revision != null && wallet.revision != revision) {
      throw const WalletFailure('conflict');
    }
    if (wallet.archived) throw const WalletFailure('archived');
    final rows = await LocalWalletRepository.entries.find(
      txn,
      finder: Finder(filter: Filter.equals('walletId', id)),
    );
    final entries =
        rows.map((e) => WalletEntry.fromJson(e.key, e.value)).toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return WalletSnapshot(wallet, entries);
  }

  Future<void> _append(
    Transaction txn,
    WalletOperation op,
    String label,
    String transferId,
    String walletId,
    Money delta,
    WalletEntryKind kind, {
    bool fee = false,
  }) async {
    final id = const Uuid().v5(op.id.value, label);
    if (await LocalWalletRepository.entries.record(id).exists(txn)) {
      throw const WalletFailure('conflict');
    }
    final snapshot = await _wallet(txn, walletId), w = snapshot.wallet;
    if (delta.currency != w.currency) throw const WalletFailure('currency');
    await LocalWalletRepository.entries
        .record(id)
        .put(
          txn,
          WalletEntry(
            operationId: id,
            walletId: walletId,
            kind: kind,
            delta: delta,
            before: snapshot.balance,
            after: snapshot.balance + delta,
            at: op.at,
            reason: label,
            sequence: w.revision + 1,
            transferId: transferId,
            transactionId: fee ? feeId(transferId) : '',
          ).toJson(),
        );
    final metadata = (await LocalWalletRepository.wallets
        .record(walletId)
        .get(txn))!;
    await LocalWalletRepository.wallets.record(walletId).put(txn, {
      ...metadata,
      'revision': w.revision + 1,
      'updatedAt': op.at.toIso8601String(),
    });
  }

  Future<void> _feeMetadata(
    Transaction txn,
    WalletOperation op,
    String id,
    TransferDraft? draft,
  ) async {
    final key = feeId(id),
        old = await LocalTransactionRepository.store.record(feeId(id)).get(txn);
    final active = draft != null && draft.fee.minorUnits > BigInt.zero;
    if (!active && old == null) return;
    final payload = active
        ? TransactionDraft(
            walletId: draft.sourceId,
            kind: TransactionKind.expense,
            amount: draft.fee,
            category: 'transferFee',
            date: calendarDate(op.at),
            notes: draft.notes,
          ).toJson()
        : old!;
    await LocalTransactionRepository.store.record(key).put(txn, {
      ...payload,
      'linkedTransferId': id,
      'revision': old == null ? 0 : (old['revision'] as int) + 1,
      'deleted': !active,
      'createdAt': old?['createdAt'] ?? op.at.toIso8601String(),
      'updatedAt': op.at.toIso8601String(),
    });
  }

  Future<void> _change(
    WalletOperation op,
    String id,
    int? revision,
    TransferDraft? draft,
    Map<String, int> walletRevisions,
  ) async {
    draft?.validate();
    final revisions = Map<String, int>.unmodifiable(walletRevisions),
        keys = walletRevisions.keys.toList()..sort();
    final request = jsonEncode([
      'transfer-v1',
      op.at.toIso8601String(),
      id,
      revision,
      draft?.toJson(),
      [
        for (final k in keys) [k, revisions[k]],
      ],
    ]);
    await db.applyOnce(op.id, request, (txn) async {
      WalletTransfer? old;
      final metadata = await store.record(id).get(txn);
      if (revision == null) {
        if (metadata != null || draft == null) {
          throw const WalletFailure('conflict');
        }
      } else {
        if (metadata == null) throw const WalletFailure('notFound');
        old = WalletTransfer.fromJson(id, metadata);
        if (old.revision != revision) throw const WalletFailure('conflict');
        if (old.cancelled) throw const WalletFailure('deleted');
        await _assertEffect(txn, old);
      }
      final involved = <String>{
        if (old != null) ...[old.draft.sourceId, old.draft.destinationId],
        if (draft != null) ...[draft.sourceId, draft.destinationId],
      };
      final snapshots = <String, WalletSnapshot>{};
      for (final key in involved) {
        if (!revisions.containsKey(key)) throw const WalletFailure('conflict');
        snapshots[key] = await _wallet(txn, key, revision: revisions[key]);
      }
      Money? received;
      if (draft != null) {
        if (snapshots[draft.sourceId]!.wallet.currency !=
            draft.amount.currency) {
          throw const WalletFailure('currency');
        }
        received = draft.quote(snapshots[draft.destinationId]!.wallet.currency);
      }
      final deltas = <String, Money>{};
      void add(String key, Money value) {
        deltas[key] =
            (deltas[key] ?? Money(BigInt.zero, value.currency)) + value;
      }

      if (old != null) {
        add(old.draft.sourceId, old.draft.amount + old.draft.fee);
        add(old.draft.destinationId, _negative(old.received));
      }
      if (draft != null) {
        add(draft.sourceId, _negative(draft.amount + draft.fee));
        add(draft.destinationId, received!);
      }
      for (final e in deltas.entries) {
        if (e.value.minorUnits < BigInt.zero &&
            (snapshots[e.key]!.balance + e.value).minorUnits < BigInt.zero) {
          throw const WalletFailure('insufficient');
        }
      }
      if (old != null) {
        await _append(
          txn,
          op,
          'reverse-out',
          id,
          old.draft.sourceId,
          old.draft.amount,
          WalletEntryKind.transferReversal,
        );
        await _append(
          txn,
          op,
          'reverse-in',
          id,
          old.draft.destinationId,
          _negative(old.received),
          WalletEntryKind.transferReversal,
        );
        if (old.draft.fee.minorUnits > BigInt.zero) {
          await _append(
            txn,
            op,
            'reverse-fee',
            id,
            old.draft.sourceId,
            old.draft.fee,
            WalletEntryKind.reversal,
            fee: true,
          );
        }
      }
      if (draft != null) {
        await _append(
          txn,
          op,
          'new-out',
          id,
          draft.sourceId,
          _negative(draft.amount),
          WalletEntryKind.transferOut,
        );
        await _append(
          txn,
          op,
          'new-in',
          id,
          draft.destinationId,
          received!,
          WalletEntryKind.transferIn,
        );
        if (draft.fee.minorUnits > BigInt.zero) {
          await _append(
            txn,
            op,
            'new-fee',
            id,
            draft.sourceId,
            _negative(draft.fee),
            WalletEntryKind.expense,
            fee: true,
          );
        }
      }
      await _feeMetadata(txn, op, id, draft);
      await store.record(id).put(txn, {
        ...(draft?.toJson() ?? metadata!),
        'received': received?.toJson() ?? old!.received.toJson(),
        'rounding': 'halfUp',
        'revision': revision == null ? 0 : revision + 1,
        'cancelled': draft == null,
        'createdAt':
            old?.createdAt.toIso8601String() ?? op.at.toIso8601String(),
        'updatedAt': op.at.toIso8601String(),
      });
      await protectSavings(txn, involved);
    });
  }

  @override
  Future<String> create(
    WalletOperation op,
    TransferDraft draft,
    Map<String, int> revisions,
  ) async {
    await _change(op, op.id.value, null, draft, revisions);
    return op.id.value;
  }

  @override
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    TransferDraft draft,
    Map<String, int> revisions,
  ) => _change(op, id, revision, draft, revisions);
  @override
  Future<void> cancel(
    WalletOperation op,
    String id,
    int revision,
    Map<String, int> revisions,
  ) => _change(op, id, revision, null, revisions);
}

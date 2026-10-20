import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/savings_reservations.dart';
import '../../../core/domain/money.dart';
import '../../wallets/data/local_wallet_repository.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/debt.dart';
import '../domain/debt_repository.dart';

final class LocalDebtRepository implements DebtRepository {
  LocalDebtRepository(this.db);
  final AppDatabase db;
  static final store = stringMapStoreFactory.store('debts'),
      cashStore = stringMapStoreFactory.store('debt_cash_events');
  Future<DebtSnapshot> _snapshot(DatabaseClient txn, Debt d) async {
    final events =
        (await cashStore.find(
            txn,
            finder: Finder(filter: Filter.equals('debtId', d.id)),
          )).map((r) => DebtCashEvent.fromJson(r.key, r.value)).toList()
          ..sort((a, b) {
            final x = b.draft.date.compareTo(a.draft.date);
            return x != 0 ? x : b.id.compareTo(a.id);
          });
    for (final e in events) {
      await _assert(txn, d, e);
    }
    return DebtSnapshot(d, events);
  }

  @override
  Future<List<DebtSnapshot>> load() => db.database.transaction((txn) async {
    final debts =
        (await store.find(txn))
            .map((r) => Debt.fromJson(r.key, r.value))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final ids = debts.map((d) => d.id).toSet();
    if ((await cashStore.find(txn))
        .any((r) => !ids.contains(r.value['debtId']))) {
      throw const WalletFailure('integrity');
    }
    return List.unmodifiable(
      await Future.wait(debts.map((d) => _snapshot(txn, d))),
    );
  });
  @override
  Stream<List<DebtSnapshot>> watch() =>
      store.query().onSnapshots(db.database).asyncMap((_) => load());
  Future<DebtSnapshot> _current(
    Transaction txn,
    String id,
    int revision,
  ) async {
    final v = await store.record(id).get(txn);
    if (v == null) {
      throw const WalletFailure('notFound');
    }
    final d = Debt.fromJson(id, v);
    if (d.revision != revision) {
      throw const WalletFailure('conflict');
    }
    return _snapshot(txn, d);
  }

  Future<void> _assert(DatabaseClient txn, Debt debt, DebtCashEvent e) async {
    final rows = await LocalWalletRepository.entries.find(
      txn,
      finder: Finder(filter: Filter.equals('debtEventId', e.id)),
    );
    if (rows.isEmpty) {
      throw const WalletFailure('integrity');
    }
    final net = <String, Money>{};
    for (final r in rows) {
      final x = WalletEntry.fromJson(r.key, r.value);
      if (![
            WalletEntryKind.debtIn,
            WalletEntryKind.debtOut,
            WalletEntryKind.debtReversal,
          ].contains(x.kind) ||
          x.delta.currency != debt.draft.principal.currency) {
        throw const WalletFailure('integrity');
      }
      net[x.walletId] =
          (net[x.walletId] ?? Money(BigInt.zero, x.delta.currency)) + x.delta;
    }
    final expected = e.cancelled
        ? Money(BigInt.zero, e.draft.amount.currency)
        : e.draft.effect(debt.draft.direction);
    if (net[e.draft.walletId] != expected ||
        net.entries.any(
          (x) => x.key != e.draft.walletId && x.value.minorUnits != BigInt.zero,
        )) {
      throw const WalletFailure('integrity');
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
        jsonEncode(['debt-v1', type, op.at.toIso8601String(), ...args]),
        run,
      )
      .then((_) {});
  @override
  Future<String> create(WalletOperation op, DebtDraft draft) async {
    draft.validate();
    await _write(op, 'create', [draft.toJson()], (txn) async {
      if (await store.record(op.id.value).exists(txn)) {
        throw const WalletFailure('conflict');
      }
      await store
          .record(op.id.value)
          .put(
            txn,
            Debt(
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
    DebtDraft draft,
  ) async {
    draft.validate();
    await _write(op, 'edit', [id, revision, draft.toJson()], (txn) async {
      final s = await _current(txn, id, revision);
      if (s.events.isNotEmpty &&
          (draft.principal != s.debt.draft.principal ||
              draft.direction != s.debt.draft.direction)) {
        throw const WalletFailure('immutableDebt');
      }
      await store.record(id).put(txn, {
        ...s.debt.toJson(),
        ...draft.toJson(),
        'revision': revision + 1,
        'updatedAt': op.at.toIso8601String(),
      });
    });
  }

  Future<void> _append(
    Transaction txn,
    WalletOperation op,
    String label,
    String eventId,
    String wid,
    Money delta,
    bool reversal,
  ) async {
    final w = await savingsWallet(txn, wid),
        id = const Uuid().v5(op.id.value, label);
    if (await LocalWalletRepository.entries.record(id).exists(txn)) {
      throw const WalletFailure('conflict');
    }
    await LocalWalletRepository.entries
        .record(id)
        .put(
          txn,
          WalletEntry(
            operationId: id,
            walletId: wid,
            kind: reversal
                ? WalletEntryKind.debtReversal
                : delta.minorUnits.isNegative
                ? WalletEntryKind.debtOut
                : WalletEntryKind.debtIn,
            delta: delta,
            before: w.balance,
            after: w.balance + delta,
            at: op.at,
            reason: '',
            sequence: w.wallet.revision + 1,
            debtEventId: eventId,
          ).toJson(),
        );
    final v = (await LocalWalletRepository.wallets.record(wid).get(txn))!;
    await LocalWalletRepository.wallets.record(wid).put(txn, {
      ...v,
      'revision': w.wallet.revision + 1,
      'updatedAt': op.at.toIso8601String(),
    });
  }

  Future<void> _cash(
    WalletOperation op,
    String debtId,
    String eventId,
    int? eventRevision,
    int debtRevision,
    DebtCashDraft? draft,
    Map<String, int> walletRevisions,
  ) async {
    draft?.validate();
    final revisions = Map<String, int>.unmodifiable(walletRevisions),
        keys = walletRevisions.keys.toList()..sort();
    await _write(
      op,
      'cash',
      [
        debtId,
        eventId,
        eventRevision,
        debtRevision,
        draft?.toJson(),
        [
          for (final k in keys) [k, revisions[k]],
        ],
      ],
      (txn) async {
        final s = await _current(txn, debtId, debtRevision);
        DebtCashEvent? old;
        if (eventRevision != null) {
          old = s.events.where((e) => e.id == eventId).firstOrNull;
          if (old == null || old.revision != eventRevision || old.cancelled) {
            throw const WalletFailure('conflict');
          }
        } else if (await cashStore.record(eventId).exists(txn) ||
            draft == null) {
          throw const WalletFailure('conflict');
        }
        if (draft != null) {
          if (old != null && old.draft.kind != draft.kind) {
            throw const WalletFailure('immutableDebt');
          }
          if (draft.amount.currency != s.debt.draft.principal.currency) {
            throw const WalletFailure('currency');
          }
          if (draft.kind == DebtEventKind.principal) {
            if (draft.amount != s.debt.draft.principal ||
                s.events.any(
                  (e) =>
                      !e.cancelled &&
                      e.id != eventId &&
                      e.draft.kind == DebtEventKind.principal,
                )) {
              throw const WalletFailure('principalRecorded');
            }
          } else {
            final paid =
                s.paid.minorUnits -
                (old?.draft.kind == DebtEventKind.payment
                    ? old!.draft.amount.minorUnits
                    : BigInt.zero) +
                draft.amount.minorUnits;
            if (paid > s.debt.draft.principal.minorUnits) {
              throw const WalletFailure('overpayment');
            }
          }
        }
        final ids = {
              if (old != null) old.draft.walletId,
              if (draft != null) draft.walletId,
            },
            before = <String, WalletSnapshot>{};
        for (final id in ids) {
          final w = await savingsWallet(txn, id);
          if (w.wallet.revision != revisions[id]) {
            throw const WalletFailure('conflict');
          }
          if (w.wallet.archived) {
            throw const WalletFailure('archived');
          }
          if (w.wallet.currency != s.debt.draft.principal.currency) {
            throw const WalletFailure('currency');
          }
          before[id] = w;
        }
        final deltas = <String, Money>{};
        void add(String id, Money m) {
          deltas[id] = (deltas[id] ?? Money(BigInt.zero, m.currency)) + m;
        }

        if (old != null) {
          final effect = old.draft.effect(s.debt.draft.direction);
          add(old.draft.walletId, Money(-effect.minorUnits, effect.currency));
        }
        if (draft != null) {
          add(draft.walletId, draft.effect(s.debt.draft.direction));
        }
        for (final e in deltas.entries) {
          if (e.value.minorUnits.isNegative &&
              (before[e.key]!.balance + e.value).minorUnits.isNegative) {
            throw const WalletFailure('insufficient');
          }
        }
        if (old != null) {
          final m = old.draft.effect(s.debt.draft.direction);
          await _append(
            txn,
            op,
            'reverse',
            eventId,
            old.draft.walletId,
            Money(-m.minorUnits, m.currency),
            true,
          );
        }
        if (draft != null) {
          await _append(
            txn,
            op,
            'new',
            eventId,
            draft.walletId,
            draft.effect(s.debt.draft.direction),
            false,
          );
        }
        await protectSavings(txn, ids);
        await cashStore
            .record(eventId)
            .put(
              txn,
              DebtCashEvent(
                id: eventId,
                debtId: debtId,
                draft: draft ?? old!.draft,
                revision: eventRevision == null ? 0 : eventRevision + 1,
                cancelled: draft == null,
                createdAt: old?.createdAt ?? op.at,
                updatedAt: op.at,
              ).toJson(),
            );
        await store.record(debtId).put(txn, {
          ...s.debt.toJson(),
          'revision': debtRevision + 1,
          'updatedAt': op.at.toIso8601String(),
        });
      },
    );
  }

  @override
  Future<String> record(
    WalletOperation op,
    String debtId,
    int debtRevision,
    DebtCashDraft draft,
    Map<String, int> wallets,
  ) async {
    await _cash(op, debtId, op.id.value, null, debtRevision, draft, wallets);
    return op.id.value;
  }

  Future<String> _debtId(String eventId) async {
    final v = await cashStore.record(eventId).get(db.database);
    if (v == null) {
      throw const WalletFailure('notFound');
    }
    return v['debtId'] as String;
  }

  @override
  Future<void> editCash(
    WalletOperation op,
    String eventId,
    int eventRevision,
    int debtRevision,
    DebtCashDraft draft,
    Map<String, int> wallets,
  ) async => _cash(
    op,
    await _debtId(eventId),
    eventId,
    eventRevision,
    debtRevision,
    draft,
    wallets,
  );
  @override
  Future<void> cancelCash(
    WalletOperation op,
    String eventId,
    int eventRevision,
    int debtRevision,
    Map<String, int> wallets,
  ) async => _cash(
    op,
    await _debtId(eventId),
    eventId,
    eventRevision,
    debtRevision,
    null,
    wallets,
  );
}

import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/savings_reservations.dart';
import '../../categories/data/local_category_repository.dart';
import '../../transactions/data/local_transaction_repository.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/recurring_payment.dart';
import '../domain/recurring_repository.dart';

final class LocalRecurringRepository implements RecurringRepository {
  LocalRecurringRepository(this.db);
  final AppDatabase db;
  static final store = stringMapStoreFactory.store('recurring_payments'),
      occurrenceStore = stringMapStoreFactory.store('recurring_occurrences');
  @override
  Future<List<RecurringPayment>> load() async {
    final rows = await store.find(db.database);
    final all =
        rows.map((r) => RecurringPayment.fromJson(r.key, r.value)).toList()
          ..sort((a, b) {
            final d = a.draft.nextDate.compareTo(b.draft.nextDate);
            return d != 0 ? d : a.id.compareTo(b.id);
          });
    return List.unmodifiable(all);
  }

  @override
  Stream<List<RecurringPayment>> watch() =>
      store.query().onSnapshots(db.database).asyncMap((_) => load());
  @override
  Future<List<RecurringOccurrence>> occurrences() async =>
      (await occurrenceStore.find(db.database))
          .map((r) => RecurringOccurrence.fromJson(r.key, r.value))
          .toList(growable: false);
  @override
  Stream<List<RecurringOccurrence>> watchOccurrences() => occurrenceStore
      .query()
      .onSnapshots(db.database)
      .asyncMap((_) => occurrences());
  Future<RecurringPayment> _current(
    Transaction txn,
    String id, {
    int? revision,
  }) async {
    final v = await store.record(id).get(txn);
    if (v == null) throw const WalletFailure('notFound');
    final p = RecurringPayment.fromJson(id, v);
    if (revision != null && p.revision != revision) {
      throw const WalletFailure('conflict');
    }
    return p;
  }

  Future<void> _validate(Transaction txn, RecurringDraft d) async {
    d.validate();
    final wallet = await savingsWallet(txn, d.walletId);
    if (wallet.wallet.archived) throw const WalletFailure('archived');
    if (wallet.wallet.currency != d.amount.currency) {
      throw const WalletFailure('currency');
    }
    await LocalCategoryRepository.requireAssignable(
      txn,
      d.category,
      TransactionKind.expense,
    );
  }

  Future<void> _write(
    WalletOperation op,
    String action,
    List<Object?> args,
    Future<void> Function(Transaction) run,
  ) => db
      .applyOnce(
        op.id,
        jsonEncode(['recurring-v1', action, op.at.toIso8601String(), ...args]),
        run,
      )
      .then((_) {});
  @override
  Future<String> create(WalletOperation op, RecurringDraft draft) async {
    draft.validate();
    await _write(op, 'create', [draft.toJson()], (txn) async {
      if (await store.record(op.id.value).exists(txn)) {
        throw const WalletFailure('conflict');
      }
      await _validate(txn, draft);
      final date = DateTime.parse(draft.nextDate);
      await store
          .record(op.id.value)
          .put(
            txn,
            RecurringPayment(
              id: op.id.value,
              draft: draft,
              status: RecurringStatus.active,
              revision: 0,
              anchorDay: date.day,
              anchorMonth: date.month,
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
    RecurringDraft draft,
  ) async {
    draft.validate();
    await _write(op, 'edit', [id, revision, draft.toJson()], (txn) async {
      final p = await _current(txn, id, revision: revision);
      if (p.status == RecurringStatus.cancelled ||
          p.status == RecurringStatus.finished) {
        throw const WalletFailure('cancelled');
      }
      if (p.lastPaidDate.isNotEmpty &&
          draft.nextDate.compareTo(p.lastPaidDate) <= 0) {
        throw const WalletFailure('alreadyProcessed');
      }
      await _validate(txn, draft);
      final date = DateTime.parse(draft.nextDate),
          reset =
              draft.nextDate != p.draft.nextDate ||
              draft.cycle != p.draft.cycle;
      await store.record(id).put(txn, {
        ...p.toJson(),
        ...draft.toJson(),
        'revision': revision + 1,
        'lastError': '',
        'anchorDay': reset ? date.day : p.anchorDay,
        'anchorMonth': reset ? date.month : p.anchorMonth,
      });
    });
  }

  @override
  Future<void> setStatus(
    WalletOperation op,
    String id,
    int revision,
    RecurringStatus status,
  ) => _write(op, 'status', [id, revision, status.name], (txn) async {
    final p = await _current(txn, id, revision: revision);
    if (p.status == RecurringStatus.cancelled ||
        p.status == RecurringStatus.finished ||
        status == RecurringStatus.finished ||
        status == p.status) {
      throw const WalletFailure('cancelled');
    }
    await store.record(id).put(txn, {
      ...p.toJson(),
      'revision': revision + 1,
      'status': status.name,
      'lastError': '',
    });
  });
  Future<void> _execute(
    Transaction txn,
    RecurringPayment p,
    WalletOperation op,
    String today,
  ) async {
    if (p.status != RecurringStatus.active ||
        p.draft.nextDate.compareTo(today) > 0) {
      throw const WalletFailure('notDue');
    }
    final key = '${p.id}:${p.draft.nextDate}';
    if (await occurrenceStore.record(key).exists(txn)) {
      throw const WalletFailure('alreadyProcessed');
    }
    await _validate(txn, p.draft);
    final w = await savingsWallet(txn, p.draft.walletId);
    if (w.balance.minorUnits < p.draft.amount.minorUnits) {
      throw const WalletFailure('insufficient');
    }
    await LocalTransactionRepository(db).createInTransaction(
      txn,
      op,
      TransactionDraft(
        walletId: p.draft.walletId,
        kind: TransactionKind.expense,
        amount: p.draft.amount,
        category: p.draft.category,
        date: p.draft.nextDate,
        notes: p.draft.name,
      ),
      {w.wallet.id: w.wallet.revision},
    );
    await occurrenceStore
        .record(key)
        .put(
          txn,
          RecurringOccurrence(
            id: key,
            scheduleId: p.id,
            date: p.draft.nextDate,
            transactionId: op.id.value,
          ).toJson(),
        );
    final next = p.after(p.draft.nextDate);
    await store.record(p.id).put(txn, {
      ...p.toJson(),
      'nextDate': next ?? p.draft.nextDate,
      'status': next == null ? RecurringStatus.finished.name : p.status.name,
      'lastPaidDate': p.draft.nextDate,
      'lastError': '',
      'revision': p.revision + 1,
    });
  }

  @override
  Future<void> payNext(
    WalletOperation op,
    String id,
    int revision,
    DateTime now,
  ) => _write(op, 'pay', [id, revision, calendarDate(now)], (txn) async {
    await _execute(
      txn,
      await _current(txn, id, revision: revision),
      op,
      calendarDate(now),
    );
  });
  @override
  Future<ProcessingResult> processDue(DateTime now, {int limit = 100}) async {
    if (limit < 1 || limit > 1000) throw ArgumentError('limit must be 1..1000');
    final today = calendarDate(now), blocked = <String>{};
    var recorded = 0;
    while (recorded < limit) {
      final candidates = (await load())
          .where(
            (p) =>
                p.status == RecurringStatus.active &&
                p.draft.automatic &&
                p.draft.nextDate.compareTo(today) <= 0 &&
                !blocked.contains(p.id),
          )
          .toList();
      if (candidates.isEmpty) break;
      final candidate = candidates.first;
      // Random operation ID and wall clock are captured before retryable storage.
      final op = WalletOperation.generate();
      try {
        final did = await db.database.transaction((txn) async {
          final p = await _current(txn, candidate.id);
          if (p.revision != candidate.revision ||
              p.status != RecurringStatus.active ||
              !p.draft.automatic ||
              p.draft.nextDate.compareTo(today) > 0) {
            return false;
          }
          await _execute(txn, p, op, today);
          return true;
        });
        if (did) recorded++;
      } on WalletFailure catch (e) {
        blocked.add(candidate.id);
        await db.database.transaction((txn) async {
          final p = await _current(txn, candidate.id);
          if (p.revision == candidate.revision && p.lastError != e.code) {
            await store.record(p.id).put(txn, {
              ...p.toJson(),
              'lastError': e.code,
              'revision': p.revision + 1,
            });
          }
        });
      }
    }
    final more = (await load()).any(
      (p) =>
          p.status == RecurringStatus.active &&
          p.draft.automatic &&
          p.draft.nextDate.compareTo(today) <= 0 &&
          !blocked.contains(p.id),
    );
    return ProcessingResult(recorded, blocked.length, more);
  }
}

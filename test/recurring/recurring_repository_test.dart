import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/recurring/data/local_recurring_repository.dart';
import 'package:kim/features/recurring/domain/recurring_payment.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/categories/data/local_category_repository.dart';
import 'package:kim/features/categories/domain/app_category.dart';
import 'package:kim/features/savings/data/local_savings_repository.dart';
import 'package:kim/features/savings/domain/savings_goal.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late LocalRecurringRepository plans;
  late LocalWalletRepository wallets;
  final ils = Currency('ILS', 2), now = DateTime(2026, 10, 17);
  late String wid;
  Future<void> open() async {
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
    plans = LocalRecurringRepository(db);
    wallets = LocalWalletRepository(db);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim-recurring-');
    await open();
    wid = await wallets.create(
      WalletOperation.generate(),
      WalletDraft(
        name: 'Cash',
        color: 'emerald',
        icon: 'cash',
        type: 'cash',
        currency: ils,
      ),
      Money.parse('1000', ils),
    );
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  RecurringDraft draft({
    String name = 'Internet',
    String amount = '10',
    String next = '2026-10-15',
    RecurringCycle cycle = RecurringCycle.daily,
    bool automatic = true,
    String category = 'bills',
    String? wallet,
    Currency? currency,
  }) => RecurringDraft(
    name: name,
    amount: Money.parse(amount, currency ?? ils),
    walletId: wallet ?? wid,
    cycle: cycle,
    nextDate: next,
    category: category,
    automatic: automatic,
  );
  Future<RecurringPayment> p(String id) async =>
      (await plans.load()).singleWhere((p) => p.id == id);
  Future<WalletSnapshot> w() async =>
      (await wallets.load()).singleWhere((w) => w.wallet.id == wid);
  Future<Map<String, int>> revisions() async => {
    for (final w in await wallets.load()) w.wallet.id: w.wallet.revision,
  };
  Matcher failure(String code) =>
      isA<WalletFailure>().having((e) => e.code, 'code', code);
  test('catch-up creates real exact expenses with historical business dates and advances each occurrence once', () async {
    final id = await plans.create(WalletOperation.generate(), draft());
    final result = await plans.processDue(now);
    expect(result.recorded, 3);
    expect((await w()).balance, Money.parse('970', ils));
    expect((await p(id)).draft.nextDate, '2026-10-18');
    expect(
      (await LocalTransactionRepository(db).load()).map((t) => t.date).toSet(),
      {'2026-10-15', '2026-10-16', '2026-10-17'},
    );
    expect((await plans.occurrences()).length, 3);
    expect((await plans.processDue(now)).recorded, 0);
    await db.close();
    await open();
    expect((await plans.processDue(now)).recorded, 0);
    expect((await w()).balance, Money.parse('970', ils));
  });
  test('close after a committed bounded batch resumes remaining dates without replay', () async {
    await plans.create(WalletOperation.generate(), draft());
    final first = await plans.processDue(now, limit: 1);
    expect(first.recorded, 1);
    expect(first.more, isTrue);
    await db.close();
    await open();
    expect((await plans.processDue(now)).recorded, 2);
    expect((await plans.occurrences()).length, 3);
    expect((await w()).entries.length, 4);
  });
  test('failure after pending ledger and expense writes rolls back cursor occurrence and wallet then recovers on reopen', () async {
    final goals = LocalSavingsRepository(db),
        goal = await goals.create(
          WalletOperation.generate(),
          GoalDraft(
            name: 'Safety',
            target: Money.parse('1000', ils),
            dueOn: '2027-01-01',
            color: 'blue',
            icon: 'shield',
          ),
        );
    await goals.allocate(
      WalletOperation.generate(),
      goal,
      0,
      wid,
      0,
      Money.parse('1000', ils),
      '',
    );
    final id = await plans.create(
      WalletOperation.generate(),
      draft(next: '2026-10-17'),
    );
    final result = await plans.processDue(now);
    expect(result.blocked, 1);
    expect(result.recorded, 0);
    expect((await p(id)).lastError, 'reserved');
    expect((await p(id)).draft.nextDate, '2026-10-17');
    expect(await plans.occurrences(), isEmpty);
    expect(await LocalTransactionRepository(db).load(), isEmpty);
    expect((await w()).entries.length, 1);
    await db.close();
    await open();
    await LocalSavingsRepository(db).allocate(
      WalletOperation.generate(),
      goal,
      1,
      wid,
      (await w()).wallet.revision,
      Money.parse('0', ils),
      '',
    );
    expect((await plans.processDue(now)).recorded, 1);
    expect((await p(id)).lastError, '');
    expect((await w()).balance, Money.parse('990', ils));
  });
  test(
    'two processors race for identical dates and debit each occurrence once',
    () async {
      await plans.create(WalletOperation.generate(), draft());
      final other = LocalRecurringRepository(db);
      final results = await Future.wait([
        plans.processDue(now),
        other.processDue(now),
      ]);
      expect(results.fold(0, (sum, r) => sum + r.recorded), 3);
      expect((await plans.occurrences()).length, 3);
      expect((await w()).balance, Money.parse('970', ils));
    },
  );
  test('insufficient funds keep next date unchanged while other plans continue; depositing permits retry', () async {
    final bad = await plans.create(
          WalletOperation.generate(),
          draft(amount: '2000'),
        ),
        good = await plans.create(
          WalletOperation.generate(),
          draft(next: '2026-10-17'),
        );
    final r = await plans.processDue(now);
    expect(r.blocked, 1);
    expect(r.recorded, 1);
    expect((await p(bad)).lastError, 'insufficient');
    expect((await p(good)).draft.nextDate, '2026-10-18');
    await wallets.adjust(
      WalletOperation.generate(),
      wid,
      (await w()).wallet.revision,
      Money.parse('10000', ils),
      'Top up',
    );
    expect((await plans.processDue(now)).recorded, 3);
    expect((await w()).balance, Money.parse('4000', ils));
  });
  test('reminder-only plans never auto-debit; explicit payment and replay are atomic', () async {
    final id = await plans.create(
      WalletOperation.generate(),
      draft(automatic: false, next: '2026-10-17'),
    );
    expect((await plans.processDue(now)).recorded, 0);
    final op = WalletOperation.generate();
    await plans.payNext(op, id, 0, now);
    await plans.payNext(op, id, 0, now);
    expect((await w()).balance, Money.parse('990', ils));
    expect((await plans.occurrences()).length, 1);
    await expectLater(
      plans.payNext(WalletOperation.generate(), id, 1, now),
      throwsA(failure('notDue')),
    );
  });
  test('pause retains overdue cursor, resume catches up, cancellation is final and retains expenses', () async {
    final id = await plans.create(WalletOperation.generate(), draft());
    await plans.setStatus(
      WalletOperation.generate(),
      id,
      0,
      RecurringStatus.paused,
    );
    expect((await plans.processDue(now)).recorded, 0);
    await plans.setStatus(
      WalletOperation.generate(),
      id,
      1,
      RecurringStatus.active,
    );
    expect((await plans.processDue(now)).recorded, 3);
    final current = await p(id);
    await plans.setStatus(
      WalletOperation.generate(),
      id,
      current.revision,
      RecurringStatus.cancelled,
    );
    expect((await plans.processDue(DateTime(2027))).recorded, 0);
    expect((await LocalTransactionRepository(db).load()).length, 3);
    await expectLater(
      plans.setStatus(
        WalletOperation.generate(),
        id,
        current.revision + 1,
        RecurringStatus.active,
      ),
      throwsA(failure('cancelled')),
    );
  });
  test('editing future terms preserves old expenses and cannot rewind a processed date', () async {
    final id = await plans.create(
      WalletOperation.generate(),
      draft(next: '2026-10-17'),
    );
    await plans.processDue(now);
    final current = await p(id);
    await expectLater(
      plans.edit(
        WalletOperation.generate(),
        id,
        current.revision,
        draft(next: '2026-10-17'),
      ),
      throwsA(failure('alreadyProcessed')),
    );
    await plans.edit(
      WalletOperation.generate(),
      id,
      current.revision,
      draft(name: 'New name', amount: '20', next: '2026-10-18'),
    );
    await plans.processDue(DateTime(2026, 10, 18));
    final tx = await LocalTransactionRepository(db).load();
    expect(tx.map((t) => t.draft.amount.decimal).toSet(), {'10.00', '20.00'});
  });
  test(
    'deleting or editing a generated expense never recreates that occurrence',
    () async {
      await plans.create(WalletOperation.generate(), draft(next: '2026-10-17'));
      await plans.processDue(now);
      final repo = LocalTransactionRepository(db),
          tx = (await repo.load()).single;
      await repo.edit(
        WalletOperation.generate(),
        tx.id,
        0,
        TransactionDraft(
          walletId: wid,
          kind: TransactionKind.expense,
          amount: Money.parse('5', ils),
          category: 'bills',
          date: tx.date,
        ),
        await revisions(),
      );
      expect((await plans.processDue(now)).recorded, 0);
      await repo.delete(
        WalletOperation.generate(),
        tx.id,
        1,
        await revisions(),
      );
      await db.close();
      await open();
      expect((await plans.processDue(now)).recorded, 0);
      expect((await plans.occurrences()).length, 1);
      expect((await w()).balance, Money.parse('1000', ils));
    },
  );
  test('monthly anchors survive February and edits of unchanged next date; yearly leap dates restore', () async {
    final id = await plans.create(
      WalletOperation.generate(),
      draft(next: '2026-01-31', cycle: RecurringCycle.monthly),
    );
    await plans.processDue(DateTime(2026, 1, 31));
    var current = await p(id);
    expect(current.draft.nextDate, '2026-02-28');
    await plans.edit(
      WalletOperation.generate(),
      id,
      current.revision,
      draft(next: '2026-02-28', cycle: RecurringCycle.monthly, name: 'Rename'),
    );
    await plans.processDue(DateTime(2026, 2, 28));
    expect((await p(id)).draft.nextDate, '2026-03-31');
    final leap = await plans.create(
      WalletOperation.generate(),
      draft(next: '2024-02-29', cycle: RecurringCycle.yearly),
    );
    await plans.processDue(DateTime(2027, 3, 1));
    current = await p(leap);
    expect(current.draft.nextDate, '2028-02-29');
  });
  test('weekly cycles and bounded calendar forecasts do not write future financial entries', () async {
    final id = await plans.create(
      WalletOperation.generate(),
      draft(next: '2026-10-17', cycle: RecurringCycle.weekly),
    );
    final current = await p(id);
    expect(current.datesIn('2026-10-01', '2026-10-31'), [
      '2026-10-17',
      '2026-10-24',
      '2026-10-31',
    ]);
    expect(await LocalTransactionRepository(db).load(), isEmpty);
    expect((await plans.processDue(DateTime(2026, 10, 16))).recorded, 0);
    expect((await plans.processDue(DateTime(2026, 10, 31))).recorded, 3);
  });
  test(
    'reaching the maximum supported calendar year finishes rather than looping',
    () async {
      final id = await plans.create(
        WalletOperation.generate(),
        draft(next: '2100-12-31'),
      );
      expect((await plans.processDue(DateTime(2100, 12, 31))).recorded, 1);
      expect((await p(id)).status, RecurringStatus.finished);
      expect((await plans.processDue(DateTime(2101))).recorded, 0);
    },
  );
  test('archived wallets and archived categories block processing without skipping dates', () async {
    final id = await plans.create(WalletOperation.generate(), draft());
    await wallets.setArchived(WalletOperation.generate(), wid, 0, true);
    expect((await plans.processDue(now)).blocked, 1);
    expect((await p(id)).lastError, 'archived');
    await wallets.setArchived(WalletOperation.generate(), wid, 1, false);
    final categories = LocalCategoryRepository(db),
        c = (await categories.load()).singleWhere((c) => c.id == 'bills');
    await categories.setArchived(
      WalletOperation.generate(),
      c.id,
      c.revision,
      true,
    );
    expect((await plans.processDue(now)).blocked, 1);
    expect((await p(id)).lastError, 'category');
    expect(await plans.occurrences(), isEmpty);
  });
  test(
    'custom categories referenced by any subscription cannot be deleted',
    () async {
      final repo = LocalCategoryRepository(db),
          id = await repo.create(
            WalletOperation.generate(),
            CategoryDraft(
              name: 'Streaming',
              kind: TransactionKind.expense,
              color: 'blue',
              icon: 'bill',
            ),
          );
      await plans.create(WalletOperation.generate(), draft(category: id));
      await expectLater(
        repo.delete(WalletOperation.generate(), id, 0),
        throwsA(failure('categoryInUse')),
      );
    },
  );
  test(
    'huge amounts and currency precision remain exact and mismatches fail',
    () async {
      final c = Currency('TOK', 6),
          other = await wallets.create(
            WalletOperation.generate(),
            WalletDraft(
              name: 'Tokens',
              color: 'blue',
              icon: 'cash',
              type: 'cash',
              currency: c,
            ),
            Money.parse('99999999999999999999.123456', c),
          );
      await plans.create(
        WalletOperation.generate(),
        draft(
          wallet: other,
          currency: c,
          amount: '99999999999999999999.123455',
          next: '2026-10-17',
        ),
      );
      await plans.processDue(now);
      expect(
        (await wallets.load())
            .singleWhere((w) => w.wallet.id == other)
            .balance
            .decimal,
        '0.000001',
      );
      await expectLater(
        plans.create(WalletOperation.generate(), draft(wallet: other)),
        throwsA(failure('currency')),
      );
    },
  );
  test('metadata create edit status retries are idempotent and stale forms conflict', () async {
    final op = WalletOperation.generate(), payload = draft();
    final id = await plans.create(op, payload);
    await plans.create(op, payload);
    expect((await plans.load()).length, 1);
    final edit = WalletOperation.generate(), next = draft(name: 'Updated');
    await plans.edit(edit, id, 0, next);
    await plans.edit(edit, id, 0, next);
    expect((await p(id)).revision, 1);
    await expectLater(
      plans.edit(WalletOperation.generate(), id, 0, next),
      throwsA(failure('conflict')),
    );
    await expectLater(
      plans.create(op, draft(name: 'Different')),
      throwsStateError,
    );
  });
  test('schema-eight upgrade preserves old data and starts without fabricated subscriptions', () async {
    final file = '${dir.path}/legacy.db',
        legacy = await databaseFactoryIo.openDatabase(file, version: 8);
    await AppDatabase.settings.record('preferences').put(legacy, {
      'languageCode': 'en',
      'theme': 'dark',
    });
    await stringMapStoreFactory.store('debts').record('old').put(legacy, {
      'sentinel': true,
    });
    await legacy.close();
    final migrated = await AppDatabase.open(databaseFactoryIo, file);
    expect(await LocalRecurringRepository(migrated).load(), isEmpty);
    expect(
      (await stringMapStoreFactory
          .store('debts')
          .record('old')
          .get(migrated.database))!['sentinel'],
      true,
    );
    expect(migrated.database.version, AppDatabase.schemaVersion);
    await migrated.close();
  });
}

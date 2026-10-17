import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/notifications/data/local_notice_repository.dart';
import 'package:kim/features/notifications/domain/notice.dart';
import 'package:kim/features/recurring/data/local_recurring_repository.dart';
import 'package:kim/features/recurring/domain/recurring_payment.dart';
import 'package:kim/features/budgets/data/local_budget_repository.dart';
import 'package:kim/features/budgets/domain/budget.dart';
import 'package:kim/features/debts/data/local_debt_repository.dart';
import 'package:kim/features/debts/domain/debt.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';

void main() {
  final now = DateTime(2026, 10, 17), ils = Currency('ILS', 2);
  late Directory dir;
  late AppDatabase db;
  late LocalNoticeRepository states;
  late LocalRecurringRepository plans;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository tx;
  late LocalDebtRepository debts;
  late LocalBudgetRepository budgets;
  late String wid;
  Future<void> open() async {
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/db');
    states = LocalNoticeRepository(db);
    plans = LocalRecurringRepository(db);
    wallets = LocalWalletRepository(db);
    tx = LocalTransactionRepository(db);
    debts = LocalDebtRepository(db);
    budgets = LocalBudgetRepository(db);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim-notice-');
    await open();
    wid = await wallets.create(
      WalletOperation.generate(),
      WalletDraft(
        name: 'Private cash',
        color: 'blue',
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
  Future<List<Notice>> notices() async => deriveNotices(
    now: now,
    schedules: await plans.load(),
    occurrences: await plans.occurrences(),
    budgets: await budgets.load(),
    debts: await debts.load(),
    transactions: await tx.load(),
    wallets: await wallets.load(),
  );
  Future<String> plan({
    String name = 'Internet',
    String date = '2026-10-17',
    bool automatic = false,
    String amount = '10',
  }) => plans.create(
    WalletOperation.generate(),
    RecurringDraft(
      name: name,
      amount: Money.parse(amount, ils),
      walletId: wid,
      cycle: RecurringCycle.monthly,
      nextDate: date,
      category: 'bills',
      automatic: automatic,
    ),
  );
  Future<Map<String, int>> revisions() async => {
    for (final w in await wallets.load()) w.wallet.id: w.wallet.revision,
  };
  test('read dismiss and preferences persist and same stable flag operation replays once', () async {
    final id = await plan(),
        notice = (await notices()).single,
        op = WalletOperation.generate();
    expect(notice.id, contains(id));
    await states.setFlag(op, notice.id, 'read', true);
    await states.setFlag(op, notice.id, 'read', true);
    await states.setFlag(
      WalletOperation.generate(),
      notice.id,
      'dismissed',
      true,
    );
    await states.setFlag(
      WalletOperation.generate(),
      'preferences',
      'enabled',
      true,
    );
    await db.close();
    await open();
    final restored = await states.load();
    expect(restored.read, {notice.id});
    expect(restored.dismissed, {notice.id});
    expect(restored.enabled, isTrue);
    await expectLater(
      states.setFlag(op, notice.id, 'read', false),
      throwsStateError,
    );
  });
  test('delivery claims are atomic and numeric native IDs are stable unique and persisted', () async {
    expect(
      await Future.wait([states.claim('a'), states.claim('a')]),
      containsAll([true, false]),
    );
    final ids = await Future.wait([
      states.nativeId('a'),
      states.nativeId('a'),
      states.nativeId('b'),
    ]);
    expect(ids[0], ids[1]);
    expect(ids[0], isNot(ids[2]));
    await db.close();
    await open();
    expect(await states.nativeId('a'), ids[0]);
    expect(await states.claim('a'), false);
    await states.release('a');
    expect(await states.claim('a'), true);
  });
  test('delivery metadata changes do not emit preference changes or cause foreground notification loops', () async {
    final values = <Object>[];
    final sub = states.watch().listen(values.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final initial = values.length;
    await states.claim('one');
    await states.nativeId('one');
    await states.release('one');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(values.length, initial);
    await states.setFlag(WalletOperation.generate(), 'one', 'read', true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(values.length, initial + 1);
    await sub.cancel();
  });
  test('upcoming reminders use a seven-day window and stable keys; paused and cancelled plans disappear', () async {
    final id = await plan();
    await plan(date: '2026-11-01');
    final first = (await notices()).single;
    expect(first.kind, NoticeKind.subscription);
    expect((await notices()).single.id, first.id);
    await plans.setStatus(
      WalletOperation.generate(),
      id,
      0,
      RecurringStatus.paused,
    );
    expect(await notices(), isEmpty);
    await plans.setStatus(
      WalletOperation.generate(),
      id,
      1,
      RecurringStatus.active,
    );
    expect((await notices()).single.id, first.id);
    await plans.setStatus(
      WalletOperation.generate(),
      id,
      2,
      RecurringStatus.cancelled,
    );
    expect(await notices(), isEmpty);
  });
  test('blocked and recorded alerts reflect real processing and deleted expenses never claim to be paid', () async {
    final id = await plan(automatic: true, amount: '2000');
    await plans.processDue(now);
    expect((await notices()).single.kind, NoticeKind.blocked);
    var p = (await plans.load()).single;
    await plans.edit(
      WalletOperation.generate(),
      id,
      p.revision,
      RecurringDraft(
        name: 'Internet',
        amount: Money.parse('10', ils),
        walletId: wid,
        cycle: RecurringCycle.monthly,
        nextDate: '2026-10-17',
        category: 'bills',
        automatic: true,
      ),
    );
    await plans.processDue(now);
    expect((await notices()).single.kind, NoticeKind.recorded);
    final t = (await tx.load()).single;
    await tx.delete(WalletOperation.generate(), t.id, 0, await revisions());
    expect((await notices()).single.kind, NoticeKind.reversed);
    expect((await plans.processDue(now)).recorded, 0);
  });
  test('budget alerts derive highest selected threshold and disappear after historical expense correction', () async {
    await budgets.create(
      WalletOperation.generate(),
      BudgetDraft(
        name: 'Monthly',
        limit: Money.parse('100', ils),
        cycle: BudgetCycle.monthly,
        startsOn: '2026-10-01',
      ),
    );
    final id = await tx.create(
      WalletOperation.generate(),
      TransactionDraft(
        walletId: wid,
        kind: TransactionKind.expense,
        amount: Money.parse('80', ils),
        category: 'bills',
        date: '2026-10-02',
      ),
      await revisions(),
    );
    expect((await notices()).single.detail, '80%');
    final key = (await notices()).single.id;
    await tx.edit(
      WalletOperation.generate(),
      id,
      0,
      TransactionDraft(
        walletId: wid,
        kind: TransactionKind.expense,
        amount: Money.parse('50', ils),
        category: 'bills',
        date: '2026-10-02',
      ),
      await revisions(),
    );
    expect((await notices()).single.detail, '50%');
    expect((await notices()).single.id, isNot(key));
    await tx.delete(WalletOperation.generate(), id, 1, await revisions());
    expect(await notices(), isEmpty);
  });
  test('debt due alerts disappear after actual complete repayment and respect hidden wallets', () async {
    final id = await debts.create(
      WalletOperation.generate(),
      DebtDraft(
        direction: DebtDirection.lent,
        person: 'Person',
        principal: Money.parse('100', ils),
        dueOn: '2026-10-15',
      ),
    );
    expect((await notices()).single.kind, NoticeKind.debt);
    await debts.record(
      WalletOperation.generate(),
      id,
      0,
      DebtCashDraft(
        kind: DebtEventKind.payment,
        walletId: wid,
        amount: Money.parse('100', ils),
        date: '2026-10-17',
      ),
      await revisions(),
    );
    expect(await notices(), isEmpty);
    await plan();
    final w = (await wallets.load()).single.wallet;
    await wallets.setHidden(WalletOperation.generate(), wid, w.revision, true);
    expect(await notices(), isEmpty);
  });
  test('all alert sources vanish while their wallet is hidden without retaining sensitive facts', () async {
    await plan(automatic: true);
    await plans.processDue(now);
    await budgets.create(
      WalletOperation.generate(),
      BudgetDraft(
        name: 'Private budget',
        limit: Money.parse('10', ils),
        cycle: BudgetCycle.monthly,
        startsOn: '2026-10-01',
      ),
    );
    expect((await notices()).length, 2);
    final w = (await wallets.load()).single.wallet;
    await wallets.setHidden(WalletOperation.generate(), wid, w.revision, true);
    expect(await notices(), isEmpty);
  });
  test('native forecast deduplicates days limits horizon and includes debts without inventing payments', () async {
    await plan(date: '2026-10-20');
    await plan(name: 'Second', date: '2026-10-20');
    await debts.create(
      WalletOperation.generate(),
      DebtDraft(
        direction: DebtDirection.borrowed,
        person: 'Lender',
        principal: Money.parse('50', ils),
        dueOn: '2026-10-22',
      ),
    );
    final days = reminderDates(now, await plans.load(), await debts.load());
    expect(days, ['2026-10-20', '2026-10-22']);
    expect(await tx.load(), isEmpty);
  });
  test('native forecast retains next monthly and yearly dates beyond the rolling month', () async {
    await plan(date: '2026-11-17');
    await plans.create(
      WalletOperation.generate(),
      RecurringDraft(
        name: 'Annual',
        amount: Money.parse('20', ils),
        walletId: wid,
        cycle: RecurringCycle.yearly,
        nextDate: '2027-10-17',
        category: 'bills',
      ),
    );
    expect(reminderDates(now, await plans.load(), []), [
      '2026-11-17',
      '2027-10-17',
    ]);
  });
}

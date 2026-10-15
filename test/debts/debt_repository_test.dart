import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/debts/data/local_debt_repository.dart';
import 'package:kim/features/debts/domain/debt.dart';
import 'package:kim/features/savings/data/local_savings_repository.dart';
import 'package:kim/features/savings/domain/savings_goal.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';

void main() {
  final ils = Currency('ILS', 2), usd = Currency('USD', 2);
  late Directory dir;
  late AppDatabase db;
  late LocalDebtRepository debts;
  late LocalWalletRepository wallets;
  Future<void> open() async {
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
    debts = LocalDebtRepository(db);
    wallets = LocalWalletRepository(db);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim-debts-');
    await open();
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  DebtDraft draft({
    DebtDirection direction = DebtDirection.lent,
    String amount = '500',
    Currency? currency,
    String person = 'Ahmad',
    String due = '2026-10-15',
  }) => DebtDraft(
    direction: direction,
    person: person,
    principal: Money.parse(amount, currency ?? ils),
    dueOn: due,
    notes: 'Agreement',
  );
  Future<String> debt({
    DebtDirection direction = DebtDirection.lent,
    String amount = '500',
    Currency? currency,
  }) => debts.create(
    WalletOperation.generate(),
    draft(direction: direction, amount: amount, currency: currency),
  );
  Future<String> wallet({String amount = '1000', Currency? currency}) =>
      wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Cash',
          color: 'blue',
          icon: 'cash',
          type: 'cash',
          currency: currency ?? ils,
        ),
        Money.parse(amount, currency ?? ils),
      );
  Future<DebtSnapshot> d(String id) async =>
      (await debts.load()).singleWhere((d) => d.debt.id == id);
  Future<WalletSnapshot> w(String id) async =>
      (await wallets.load()).singleWhere((w) => w.wallet.id == id);
  Future<Map<String, int>> revisions() async => {
    for (final w in await wallets.load()) w.wallet.id: w.wallet.revision,
  };
  DebtCashDraft cash(
    String wid,
    String amount, {
    DebtEventKind kind = DebtEventKind.payment,
    Currency? currency,
    String date = '2026-10-15',
  }) => DebtCashDraft(
    kind: kind,
    walletId: wid,
    amount: Money.parse(amount, currency ?? ils),
    date: date,
    note: 'Receipt',
  );
  Future<String> pay(
    String id,
    String wid,
    String amount, {
    DebtEventKind kind = DebtEventKind.payment,
    Currency? currency,
  }) async => debts.record(
    WalletOperation.generate(),
    id,
    (await d(id)).debt.revision,
    cash(wid, amount, kind: kind, currency: currency),
    await revisions(),
  );
  Future<void> cancel(String id, String event) async {
    final s = await d(id), e = s.events.singleWhere((e) => e.id == event);
    await debts.cancelCash(
      WalletOperation.generate(),
      event,
      e.revision,
      s.debt.revision,
      await revisions(),
    );
  }

  Matcher failure(String code) =>
      isA<WalletFailure>().having((e) => e.code, 'code', code);
  test('administrative creation metadata edit and replay never affect cash or income expenses', () async {
    final wid = await wallet(),
        op = WalletOperation.generate(),
        initial = draft();
    final id = await debts.create(op, initial);
    await debts.create(op, initial);
    await debts.edit(
      WalletOperation.generate(),
      id,
      0,
      draft(person: 'Ali', amount: '600'),
    );
    expect((await w(wid)).balance, Money.parse('1000', ils));
    expect((await w(wid)).entries.length, 1);
    expect((await d(id)).remaining, Money.parse('600', ils));
    expect(await LocalTransactionRepository(db).load(), isEmpty);
    await db.close();
    await open();
    expect((await d(id)).debt.draft.person, 'Ali');
    await expectLater(
      debts.create(op, draft(person: 'Different')),
      throwsStateError,
    );
  });
  for (final direction in DebtDirection.values) {
    test(
      '$direction original cash is explicit and cannot be recorded twice',
      () async {
        final wid = await wallet(), id = await debt(direction: direction);
        expect((await w(wid)).balance, Money.parse('1000', ils));
        await pay(id, wid, '500', kind: DebtEventKind.principal);
        expect(
          (await w(wid)).balance,
          Money.parse(direction == DebtDirection.lent ? '500' : '1500', ils),
        );
        expect((await d(id)).paid.minorUnits, BigInt.zero);
        await expectLater(
          pay(id, wid, '500', kind: DebtEventKind.principal),
          throwsA(failure('principalRecorded')),
        );
        expect((await d(id)).events.length, 1);
      },
    );
    test(
      '$direction partial full edited and cancelled repayments compute exact cash and outstanding',
      () async {
        final wid = await wallet(),
            id = await debt(direction: direction),
            event = await pay(id, wid, '123.45');
        expect((await d(id)).remaining, Money.parse('376.55', ils));
        expect(
          (await w(wid)).balance,
          Money.parse(
            direction == DebtDirection.lent ? '1123.45' : '876.55',
            ils,
          ),
        );
        await debts.editCash(
          WalletOperation.generate(),
          event,
          0,
          1,
          cash(wid, '200'),
          await revisions(),
        );
        expect((await d(id)).paid, Money.parse('200', ils));
        await pay(id, wid, '300');
        expect(
          (await d(id)).status(DateTime(2026, 10, 16)),
          DebtStatus.settled,
        );
        await cancel(id, event);
        expect((await d(id)).remaining, Money.parse('200', ils));
        expect(
          (await d(id)).status(DateTime(2026, 10, 16)),
          DebtStatus.overdue,
        );
        expect(
          (await w(wid)).balance,
          Money.parse(direction == DebtDirection.lent ? '1300' : '700', ils),
        );
        expect((await w(wid)).entries.length, 6);
        expect(await LocalTransactionRepository(db).load(), isEmpty);
        await db.close();
        await open();
        expect((await d(id)).events.where((e) => e.cancelled).length, 1);
      },
    );
  }
  test('overpayment, negative zero invalid date and precision reject without receipts or partial writes', () async {
    final wid = await wallet(), id = await debt();
    final count = await stringMapStoreFactory
        .store('operation_receipts')
        .count(db.database);
    for (final amount in ['500.01', '0', '-1']) {
      await expectLater(pay(id, wid, amount), throwsA(isA<WalletFailure>()));
    }
    await expectLater(
      debts.record(
        WalletOperation.generate(),
        id,
        0,
        cash(wid, '1', date: '2026-02-30'),
        await revisions(),
      ),
      throwsA(isA<WalletFailure>()),
    );
    expect(() => Money.parse('1.001', ils), throwsFormatException);
    expect((await d(id)).events, isEmpty);
    expect((await w(wid)).entries.length, 1);
    expect(
      await stringMapStoreFactory
          .store('operation_receipts')
          .count(db.database),
      count,
    );
    for (final invalid in [
      draft(person: ''),
      draft(amount: '0'),
      draft(due: 'bad'),
    ]) {
      await expectLater(
        debts.create(WalletOperation.generate(), invalid),
        throwsA(isA<WalletFailure>()),
      );
    }
  });
  test(
    'different currency or same code with different precision is rejected',
    () async {
      final id = await debt(),
          a = await wallet(currency: usd),
          b = await wallet(currency: Currency('ILS', 3));
      await expectLater(
        pay(id, a, '1', currency: usd),
        throwsA(failure('currency')),
      );
      await expectLater(pay(id, b, '1'), throwsA(failure('currency')));
      expect((await d(id)).events, isEmpty);
    },
  );
  test('huge six-place amounts are exact beyond JS safe integers', () async {
    final c = Currency('TOK', 6),
        wid = await wallet(amount: '9999999999999999999999', currency: c),
        id = await debt(amount: '9999999999999999999999.123456', currency: c);
    await pay(id, wid, '9999999999999999999999.123455', currency: c);
    expect((await d(id)).remaining.decimal, '0.000001');
    await pay(id, wid, '0.000001', currency: c);
    expect((await d(id)).progress, 1);
    expect((await d(id)).remaining.minorUnits, BigInt.zero);
  });
  test('changing payment wallet reverses previous cash and writes replacement in one transaction', () async {
    final a = await wallet(),
        b = await wallet(),
        id = await debt(),
        event = await pay(id, a, '100');
    await debts.editCash(
      WalletOperation.generate(),
      event,
      0,
      1,
      cash(b, '200'),
      await revisions(),
    );
    expect((await w(a)).balance, Money.parse('1000', ils));
    expect((await w(b)).balance, Money.parse('1200', ils));
    expect((await d(id)).paid, Money.parse('200', ils));
    await cancel(id, event);
    expect((await w(b)).balance, Money.parse('1000', ils));
    expect((await d(id)).remaining, Money.parse('500', ils));
  });
  test('insufficient outgoing or received-cash reversal rolls back and preserves event status', () async {
    final wid = await wallet(amount: '0'),
        id = await debt(direction: DebtDirection.borrowed);
    await expectLater(pay(id, wid, '1'), throwsA(failure('insufficient')));
    final receipt = await pay(id, wid, '500', kind: DebtEventKind.principal);
    await wallets.adjust(
      WalletOperation.generate(),
      wid,
      (await w(wid)).wallet.revision,
      Money.parse('1', ils),
      'Spent elsewhere',
    );
    await expectLater(cancel(id, receipt), throwsA(failure('insufficient')));
    expect((await d(id)).events.single.cancelled, isFalse);
    expect((await w(wid)).balance, Money.parse('1', ils));
  });
  test('savings reservations protect debt payments and incoming cancellation with valid final-net edits allowed', () async {
    final wid = await wallet(),
        id = await debt(direction: DebtDirection.borrowed),
        goals = LocalSavingsRepository(db);
    final goal = await goals.create(
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
      Money.parse('900', ils),
      '',
    );
    await expectLater(pay(id, wid, '100.01'), throwsA(failure('reserved')));
    await pay(id, wid, '100');
    expect((await w(wid)).balance, Money.parse('900', ils));
    final lent = await debt(), incoming = await pay(lent, wid, '100');
    await goals.allocate(
      WalletOperation.generate(),
      goal,
      1,
      wid,
      (await w(wid)).wallet.revision,
      Money.parse('1000', ils),
      '',
    );
    await expectLater(cancel(lent, incoming), throwsA(failure('reserved')));
    await debts.editCash(
      WalletOperation.generate(),
      incoming,
      0,
      1,
      cash(wid, '101'),
      await revisions(),
    );
    expect((await w(wid)).balance, Money.parse('1001', ils));
  });
  test('stable payment operation survives reopen and concurrent replay without double effect', () async {
    final wid = await wallet(),
        id = await debt(),
        op = WalletOperation.generate(),
        r = await revisions(),
        payload = cash(wid, '200');
    Future<String> apply() => debts.record(op, id, 0, payload, r);
    await Future.wait([apply(), apply()]);
    await db.close();
    await open();
    await apply();
    expect((await d(id)).events.length, 1);
    expect((await w(wid)).balance, Money.parse('1200', ils));
    await expectLater(
      debts.record(op, id, 0, cash(wid, '201'), r),
      throwsStateError,
    );
  });
  test('concurrent payments use debt revision to prevent overpayment; stale wallets conflict', () async {
    final a = await wallet(),
        b = await wallet(),
        id = await debt(),
        revs = await revisions();
    final results = await Future.wait(
      [a, b].map((wid) async {
        try {
          await debts.record(
            WalletOperation.generate(),
            id,
            0,
            cash(wid, '400'),
            revs,
          );
          return true;
        } on WalletFailure {
          return false;
        }
      }),
    );
    expect(results.where((v) => v).length, 1);
    expect((await d(id)).paid, Money.parse('400', ils));
    final current = await d(id), used = current.events.single.draft.walletId;
    await expectLater(
      debts.record(
        WalletOperation.generate(),
        id,
        current.debt.revision,
        cash(used, '50'),
        revs,
      ),
      throwsA(failure('conflict')),
    );
  });
  test('principal remains fixed after history; person notes and due date can change', () async {
    final wid = await wallet(),
        id = await debt(),
        event = await pay(id, wid, '100');
    await cancel(id, event);
    await expectLater(
      debts.edit(WalletOperation.generate(), id, 2, draft(amount: '600')),
      throwsA(failure('immutableDebt')),
    );
    await expectLater(
      debts.edit(
        WalletOperation.generate(),
        id,
        2,
        draft(direction: DebtDirection.borrowed),
      ),
      throwsA(failure('immutableDebt')),
    );
    await debts.edit(
      WalletOperation.generate(),
      id,
      2,
      draft(person: 'Updated', due: '2027-01-01'),
    );
    expect((await d(id)).debt.draft.person, 'Updated');
  });
  test('principal movement edits and cancellation keep administrative balance and receipts history', () async {
    final a = await wallet(),
        b = await wallet(),
        id = await debt(),
        event = await pay(id, a, '500', kind: DebtEventKind.principal);
    await debts.editCash(
      WalletOperation.generate(),
      event,
      0,
      1,
      cash(b, '500', kind: DebtEventKind.principal),
      await revisions(),
    );
    expect((await w(a)).balance, Money.parse('1000', ils));
    expect((await w(b)).balance, Money.parse('500', ils));
    await cancel(id, event);
    expect((await w(b)).balance, Money.parse('1000', ils));
    expect((await d(id)).remaining, Money.parse('500', ils));
    await pay(id, a, '500', kind: DebtEventKind.principal);
    expect((await d(id)).principalRecorded, isTrue);
  });
  test('archived wallets reject cash changes while hidden wallet privacy includes cancelled history', () async {
    final wid = await wallet(),
        id = await debt(),
        event = await pay(id, wid, '1');
    await wallets.setHidden(
      WalletOperation.generate(),
      wid,
      (await w(wid)).wallet.revision,
      true,
    );
    expect((await d(id)).concealed(await wallets.load()), isTrue);
    await cancel(id, event);
    expect((await d(id)).concealed(await wallets.load()), isTrue);
    await wallets.setArchived(
      WalletOperation.generate(),
      wid,
      (await w(wid)).wallet.revision,
      true,
    );
    await expectLater(pay(id, wid, '1'), throwsA(failure('archived')));
  });
  test('due today is active, next day overdue, and full repayment overrides overdue', () async {
    final wid = await wallet(), id = await debt();
    expect((await d(id)).status(DateTime(2026, 10, 15, 23)), DebtStatus.active);
    expect((await d(id)).status(DateTime(2026, 10, 16)), DebtStatus.overdue);
    await pay(id, wid, '500');
    expect((await d(id)).status(DateTime(2100)), DebtStatus.settled);
  });
  test('schema-seven upgrade adds no debts and preserves preferences and savings metadata', () async {
    final path = '${dir.path}/legacy.db',
        legacy = await databaseFactoryIo.openDatabase(path, version: 7);
    await AppDatabase.settings.record('preferences').put(legacy, {
      'languageCode': 'en',
      'theme': 'dark',
    });
    await stringMapStoreFactory.store('savings_goals').record('sentinel').put(
      legacy,
      {'test': 'preserved'},
    );
    await legacy.close();
    final migrated = await AppDatabase.open(databaseFactoryIo, path);
    expect(await LocalDebtRepository(migrated).load(), isEmpty);
    expect(
      (await stringMapStoreFactory
          .store('savings_goals')
          .record('sentinel')
          .get(migrated.database))!['test'],
      'preserved',
    );
    expect(migrated.database.version, 8);
    await migrated.close();
  });
}

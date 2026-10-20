import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/data/savings_reservations.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/savings/data/local_savings_repository.dart';
import 'package:kim/features/savings/domain/savings_goal.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/domain/wallet_transfer.dart';
import 'package:kim/features/transfers/domain/exchange_rate.dart';

void main() {
  final ils = Currency('ILS', 2), usd = Currency('USD', 2);
  late Directory dir;
  late AppDatabase db;
  late LocalSavingsRepository goals;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository tx;
  late LocalTransferRepository transfers;
  Future<void> open() async {
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
    goals = LocalSavingsRepository(db);
    wallets = LocalWalletRepository(db);
    tx = LocalTransactionRepository(db);
    transfers = LocalTransferRepository(db);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim-savings-');
    await open();
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  GoalDraft draft({
    String name = 'A home',
    String target = '500',
    Currency? currency,
    String date = '2027-01-01',
    String color = 'blue',
    String icon = 'home',
  }) => GoalDraft(
    name: name,
    target: Money.parse(target, currency ?? ils),
    dueOn: date,
    color: color,
    icon: icon,
  );
  Future<String> goal({String target = '500', Currency? currency}) =>
      goals.create(
        WalletOperation.generate(),
        draft(target: target, currency: currency),
      );
  Future<String> wallet({String balance = '1000', Currency? currency}) =>
      wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Cash',
          color: 'emerald',
          icon: 'wallet',
          type: 'cash',
          currency: currency ?? ils,
        ),
        Money.parse(balance, currency ?? ils),
      );
  Future<WalletSnapshot> w(String id) async =>
      (await wallets.load()).singleWhere((w) => w.wallet.id == id);
  Future<GoalSnapshot> g(String id) async =>
      (await goals.load()).singleWhere((g) => g.goal.id == id);
  Future<Map<String, int>> revs() async => {
    for (final w in await wallets.load()) w.wallet.id: w.wallet.revision,
  };
  Future<void> allocate(
    String id,
    String wid,
    String amount, {
    Currency? currency,
    String note = '',
  }) async => goals.allocate(
    WalletOperation.generate(),
    id,
    (await g(id)).goal.revision,
    wid,
    (await w(wid)).wallet.revision,
    Money.parse(amount, currency ?? ils),
    note,
  );
  Future<Money> reserved(String id) async =>
      reservedInWallet(db.database, id, (await w(id)).wallet.currency);
  Future<Money> available(String id) async =>
      (await w(id)).balance - await reserved(id);
  TransactionDraft transaction(
    String id,
    String amount, {
    bool income = false,
    Currency? currency,
  }) => TransactionDraft(
    walletId: id,
    kind: income ? TransactionKind.income : TransactionKind.expense,
    amount: Money.parse(amount, currency ?? ils),
    category: income ? 'salary' : 'food',
    date: '2026-01-01',
  );
  Future<String> transact(
    String id,
    String amount, {
    bool income = false,
  }) async => tx.create(
    WalletOperation.generate(),
    transaction(id, amount, income: income),
    await revs(),
  );
  final failure = isA<WalletFailure>();
  Matcher code(String c) =>
      isA<WalletFailure>().having((e) => e.code, 'code', c);

  test(
    'new store has no fabricated goals and preserves legacy schema-six data',
    () async {
      await db.close();
      final legacy = await databaseFactoryIo.openDatabase(
        '${dir.path}/legacy.db',
        version: 6,
      );
      await AppDatabase.settings.record('preferences').put(legacy, {
        'languageCode': 'en',
        'theme': 'dark',
      });
      await stringMapStoreFactory.store('budgets').record('old').put(legacy, {
        'sentinel': 'unchanged',
      });
      await legacy.close();
      final migrated = await AppDatabase.open(
        databaseFactoryIo,
        '${dir.path}/legacy.db',
      );
      expect(await LocalSavingsRepository(migrated).load(), isEmpty);
      expect(
        (await AppDatabase.settings
            .record('preferences')
            .get(migrated.database))!['languageCode'],
        'en',
      );
      expect(
        (await stringMapStoreFactory
            .store('budgets')
            .record('old')
            .get(migrated.database))!['sentinel'],
        'unchanged',
      );
      expect(migrated.database.version, AppDatabase.schemaVersion);
      await migrated.close();
      await open();
    },
  );
  test('exact contributions persist and never create balances transactions or transfer effects', () async {
    final wid = await wallet(), id = await goal();
    final before = await w(wid);
    await allocate(id, wid, '123.45', note: 'First milestone');
    expect((await g(id)).allocated, Money.parse('123.45', ils));
    expect((await w(wid)).balance, before.balance);
    expect((await w(wid)).entries.length, before.entries.length);
    expect(await tx.load(), isEmpty);
    expect(await transfers.load(), isEmpty);
    expect(await available(wid), Money.parse('876.55', ils));
    await db.close();
    await open();
    expect((await g(id)).events.single.note, 'First milestone');
    expect(await reserved(wid), Money.parse('123.45', ils));
  });
  test('allocation is a new total, supports partial and full release with immutable signed history', () async {
    final wid = await wallet(), id = await goal();
    await allocate(id, wid, '200');
    await allocate(id, wid, '150');
    await allocate(id, wid, '0');
    final s = await g(id);
    expect(s.allocated.minorUnits, BigInt.zero);
    expect(s.events.length, 3);
    expect(s.events.map((e) => e.delta.minorUnits).toSet(), {
      BigInt.from(20000),
      BigInt.from(-5000),
      BigInt.from(-15000),
    });
    expect(await available(wid), Money.parse('1000', ils));
  });
  test(
    'reservations aggregate across goals and wallets without over-allocation',
    () async {
      final a = await wallet(),
          b = await wallet(balance: '250'),
          x = await goal(target: '1200'),
          y = await goal();
      await allocate(x, a, '800');
      await allocate(y, a, '200');
      await allocate(x, b, '250');
      expect(await available(a), Money.parse('0', ils));
      expect(await available(b), Money.parse('0', ils));
      await expectLater(allocate(y, a, '200.01'), throwsA(code('reserved')));
      expect((await g(x)).allocated, Money.parse('1050', ils));
      expect((await g(y)).events.length, 1);
      expect((await w(a)).balance, Money.parse('1000', ils));
    },
  );
  test('target cap zero negative malformed precision invalid metadata and currency mismatch are rejected', () async {
    final wid = await wallet(),
        id = await goal(),
        dollar = await wallet(currency: usd),
        scaled = await wallet(currency: Currency('ILS', 3));
    await expectLater(
      allocate(id, wid, '500.01'),
      throwsA(code('aboveTarget')),
    );
    await expectLater(allocate(id, wid, '-0.01'), throwsA(failure));
    await expectLater(allocate(id, wid, '0'), throwsA(code('noChange')));
    await expectLater(
      allocate(id, dollar, '1', currency: usd),
      throwsA(code('currency')),
    );
    await expectLater(
      allocate(id, scaled, '1', currency: Currency('ILS', 3)),
      throwsA(code('currency')),
    );
    expect(() => Money.parse('1.001', ils), throwsFormatException);
    for (final d in [
      draft(target: '0'),
      draft(target: '-1'),
      draft(date: '2026-02-30'),
      draft(name: ' '),
      draft(icon: 'bad'),
      draft(color: 'bad'),
    ]) {
      await expectLater(
        goals.create(WalletOperation.generate(), d),
        throwsA(failure),
      );
    }
    expect((await g(id)).events, isEmpty);
  });
  test(
    'huge amounts above JS safe integer and 6-place currency remain exact',
    () async {
      final c = Currency('TOK', 6),
          wid = await wallet(
            balance: '99999999999999999999999.123456',
            currency: c,
          ),
          id = await goal(
            target: '99999999999999999999999.123456',
            currency: c,
          );
      await allocate(id, wid, '99999999999999999999999.123455', currency: c);
      expect((await available(wid)).decimal, '0.000001');
      expect((await g(id)).percentage, '99.9%');
      expect((await g(id)).progress, lessThan(1));
      await allocate(id, wid, '99999999999999999999999.123456', currency: c);
      expect((await g(id)).achieved, isTrue);
      expect((await g(id)).percentage, '100.0%');
      expect((await g(id)).progress, 1);
    },
  );
  test('same stable allocation operation replays once; reuse with different payload fails', () async {
    final wid = await wallet(),
        id = await goal(),
        op = WalletOperation.generate(),
        wr = (await w(wid)).wallet.revision;
    Future<void> apply() =>
        goals.allocate(op, id, 0, wid, wr, Money.parse('200', ils), 'one');
    await Future.wait([apply(), apply()]);
    await db.close();
    await open();
    await apply();
    expect((await g(id)).events.length, 1);
    expect((await g(id)).goal.revision, 1);
    await expectLater(
      goals.allocate(op, id, 0, wid, wr, Money.parse('201', ils), 'one'),
      throwsStateError,
    );
  });
  test('concurrent goals cannot reserve the same funds and failed attempt rolls back atomically', () async {
    final wid = await wallet(),
        x = await goal(target: '1000'),
        y = await goal(target: '1000');
    final beforeReceipts = await stringMapStoreFactory
        .store('operation_receipts')
        .count(db.database);
    final outcomes = await Future.wait(
      [x, y].map((id) async {
        try {
          await goals.allocate(
            WalletOperation.generate(),
            id,
            0,
            wid,
            0,
            Money.parse('700', ils),
            '',
          );
          return true;
        } on WalletFailure {
          return false;
        }
      }),
    );
    expect(outcomes.where((e) => e).length, 1);
    expect(await reserved(wid), Money.parse('700', ils));
    expect(
      await stringMapStoreFactory
          .store('operation_receipts')
          .count(db.database),
      beforeReceipts + 1,
    );
    expect((await wallets.load()).single.entries.length, 1);
  });
  test('stale wallet and goal revisions conflict and archived or hidden wallets have correct policy', () async {
    final wid = await wallet(), id = await goal();
    await allocate(id, wid, '100');
    await expectLater(
      goals.allocate(
        WalletOperation.generate(),
        id,
        0,
        wid,
        (await w(wid)).wallet.revision,
        Money.parse('200', ils),
        '',
      ),
      throwsA(code('conflict')),
    );
    await expectLater(
      goals.allocate(
        WalletOperation.generate(),
        id,
        1,
        wid,
        0,
        Money.parse('200', ils),
        '',
      ),
      throwsA(code('conflict')),
    );
    await wallets.setHidden(
      WalletOperation.generate(),
      wid,
      (await w(wid)).wallet.revision,
      true,
    );
    expect((await g(id)).concealed(await wallets.load()), isTrue);
    await expectLater(
      wallets.setArchived(
        WalletOperation.generate(),
        wid,
        (await w(wid)).wallet.revision,
        true,
      ),
      throwsA(code('reserved')),
    );
    await allocate(id, wid, '0');
    await wallets.setArchived(
      WalletOperation.generate(),
      wid,
      (await w(wid)).wallet.revision,
      true,
    );
    await expectLater(allocate(id, wid, '1'), throwsA(code('archived')));
  });
  test('goal metadata edit preserves history; cannot reduce target below allocated or change currency', () async {
    final wid = await wallet(), id = await goal();
    await allocate(id, wid, '200');
    await goals.edit(
      WalletOperation.generate(),
      id,
      1,
      draft(
        name: 'New name',
        target: '600',
        color: 'rose',
        icon: 'travel',
        date: '2028-12-31',
      ),
    );
    final s = await g(id);
    expect(s.goal.draft.name, 'New name');
    expect(s.goal.draft.icon, 'travel');
    expect(s.events.length, 1);
    await expectLater(
      goals.edit(WalletOperation.generate(), id, 2, draft(target: '199.99')),
      throwsA(code('belowAllocated')),
    );
    await expectLater(
      goals.edit(WalletOperation.generate(), id, 2, draft(currency: usd)),
      throwsA(code('currency')),
    );
    await allocate(id, wid, '100');
    await goals.edit(WalletOperation.generate(), id, 3, draft(target: '100'));
    expect((await g(id)).achieved, isTrue);
  });
  test('closing releases every wallet atomically retaining historic completion and idempotency', () async {
    final a = await wallet(), b = await wallet(), id = await goal();
    await allocate(id, a, '200');
    await allocate(id, b, '300');
    final op = WalletOperation.generate();
    await goals.close(op, id, 2);
    await goals.close(op, id, 2);
    final s = await g(id);
    expect(s.goal.closed, isTrue);
    expect(s.allocated.minorUnits, BigInt.zero);
    expect(s.displayed, Money.parse('500', ils));
    expect(s.achieved, isTrue);
    expect(s.events.length, 4);
    expect(s.events.where((e) => e.closing).length, 2);
    expect(await available(a), Money.parse('1000', ils));
    expect(await available(b), Money.parse('1000', ils));
    await expectLater(allocate(id, a, '1'), throwsA(code('closedGoal')));
    await expectLater(
      goals.edit(WalletOperation.generate(), id, s.goal.revision, draft()),
      throwsA(code('closedGoal')),
    );
    await db.close();
    await open();
    expect((await g(id)).displayed, s.displayed);
  });
  test('empty and partially funded goals close without falsely counting as achieved', () async {
    final a = await wallet(), empty = await goal(), partial = await goal();
    await allocate(partial, a, '25');
    await goals.close(WalletOperation.generate(), empty, 0);
    await goals.close(WalletOperation.generate(), partial, 1);
    expect((await g(empty)).displayed.minorUnits, BigInt.zero);
    expect((await g(empty)).achieved, isFalse);
    expect((await g(partial)).displayed, Money.parse('25', ils));
    expect((await g(partial)).achieved, isFalse);
    expect(await reserved(a), Money.parse('0', ils));
  });
  test('expense creation and balance adjustment protect reservations including exact boundary', () async {
    final wid = await wallet(), id = await goal();
    await allocate(id, wid, '400');
    await expectLater(transact(wid, '600.01'), throwsA(code('reserved')));
    expect(await tx.load(), isEmpty);
    await transact(wid, '600');
    expect(await available(wid), Money.parse('0', ils));
    await expectLater(
      wallets.adjust(
        WalletOperation.generate(),
        wid,
        (await w(wid)).wallet.revision,
        Money.parse('399.99', ils),
        'correction',
      ),
      throwsA(code('reserved')),
    );
    expect((await w(wid)).balance, Money.parse('400', ils));
    await allocate(id, wid, '399');
    await wallets.adjust(
      WalletOperation.generate(),
      wid,
      (await w(wid)).wallet.revision,
      Money.parse('399', ils),
      'correction',
    );
    expect((await w(wid)).balance, Money.parse('399', ils));
  });
  test('old income deletion or moving it to another wallet rolls back when savings rely on it', () async {
    final a = await wallet(balance: '0'),
        b = await wallet(),
        income = await transact(a, '500', income: true),
        id = await goal();
    await allocate(id, a, '500');
    await expectLater(
      tx.delete(WalletOperation.generate(), income, 0, await revs()),
      throwsA(code('reserved')),
    );
    await expectLater(
      tx.edit(
        WalletOperation.generate(),
        income,
        0,
        transaction(b, '500', income: true),
        await revs(),
      ),
      throwsA(code('reserved')),
    );
    expect((await tx.load()).single.deleted, isFalse);
    expect((await w(a)).balance, Money.parse('500', ils));
    expect((await w(b)).balance, Money.parse('1000', ils));
    // The intermediate reversal is below the reserve; the final net is valid.
    await tx.edit(
      WalletOperation.generate(),
      income,
      0,
      transaction(a, '501', income: true),
      await revs(),
    );
    expect((await w(a)).balance, Money.parse('501', ils));
    await allocate(id, a, '0');
    await tx.delete(WalletOperation.generate(), income, 1, await revs());
    expect((await w(a)).balance, Money.parse('0', ils));
  });
  test('expense edits, wallet reassignment and deletion recompute final available funds', () async {
    final a = await wallet(),
        b = await wallet(),
        e = await transact(a, '300'),
        id = await goal();
    await allocate(id, a, '500');
    await expectLater(
      tx.edit(
        WalletOperation.generate(),
        e,
        0,
        transaction(a, '500.01'),
        await revs(),
      ),
      throwsA(code('reserved')),
    );
    await tx.edit(
      WalletOperation.generate(),
      e,
      0,
      transaction(a, '500'),
      await revs(),
    );
    expect(await available(a), Money.parse('0', ils));
    await tx.edit(
      WalletOperation.generate(),
      e,
      1,
      transaction(b, '500'),
      await revs(),
    );
    expect(await available(a), Money.parse('500', ils));
    await tx.delete(WalletOperation.generate(), e, 2, await revs());
    expect(await available(b), Money.parse('1000', ils));
  });
  TransferDraft transfer(
    String a,
    String b,
    String amount, {
    String fee = '0',
  }) => TransferDraft(
    sourceId: a,
    destinationId: b,
    amount: Money.parse(amount, ils),
    fee: Money.parse(fee, ils),
    rate: ExchangeRate.parse('1'),
  );
  test('transfer including fees respects source reserve and no transfer principal is counted twice', () async {
    final a = await wallet(), b = await wallet(balance: '0'), id = await goal();
    await allocate(id, a, '400');
    await expectLater(
      transfers.create(
        WalletOperation.generate(),
        transfer(a, b, '600', fee: '0.01'),
        await revs(),
      ),
      throwsA(code('reserved')),
    );
    expect(await transfers.load(), isEmpty);
    expect(await tx.load(), isEmpty);
    await transfers.create(
      WalletOperation.generate(),
      transfer(a, b, '599', fee: '1'),
      await revs(),
    );
    expect((await w(a)).balance, Money.parse('400', ils));
    expect((await w(b)).balance, Money.parse('599', ils));
    expect((await tx.load()).single.draft.amount, Money.parse('1', ils));
    expect((await g(id)).allocated, Money.parse('400', ils));
  });
  test('transfer edit and cancellation protect reserved receiving funds with atomic rollback', () async {
    final a = await wallet(),
        b = await wallet(balance: '0'),
        t = await transfers.create(
          WalletOperation.generate(),
          transfer(a, b, '500'),
          await revs(),
        ),
        id = await goal();
    await allocate(id, b, '400');
    await expectLater(
      transfers.cancel(WalletOperation.generate(), t, 0, await revs()),
      throwsA(code('reserved')),
    );
    await expectLater(
      transfers.edit(
        WalletOperation.generate(),
        t,
        0,
        transfer(a, b, '399'),
        await revs(),
      ),
      throwsA(code('reserved')),
    );
    await transfers.edit(
      WalletOperation.generate(),
      t,
      0,
      transfer(a, b, '400'),
      await revs(),
    );
    expect((await w(b)).balance, Money.parse('400', ils));
    await allocate(id, b, '0');
    await transfers.cancel(WalletOperation.generate(), t, 1, await revs());
    expect((await w(a)).balance, Money.parse('1000', ils));
    expect((await w(b)).balance, Money.parse('0', ils));
  });
  test('moving earmarked savings is explicit release then actual transfer then destination allocation', () async {
    final a = await wallet(), b = await wallet(balance: '0'), id = await goal();
    await allocate(id, a, '500');
    await allocate(id, a, '0');
    await transfers.create(
      WalletOperation.generate(),
      transfer(a, b, '500'),
      await revs(),
    );
    await allocate(id, b, '500');
    expect((await w(a)).balance, Money.parse('500', ils));
    expect((await w(b)).balance, Money.parse('500', ils));
    expect((await g(id)).allocated, Money.parse('500', ils));
    expect(await reserved(a), Money.parse('0', ils));
    expect(await available(b), Money.parse('0', ils));
    expect(await tx.load(), isEmpty);
  });
  test('negative balance wallet cannot allocate, and existing debt behavior without reservations is preserved', () async {
    final a = await wallet(balance: '-10'), id = await goal();
    await expectLater(allocate(id, a, '1'), throwsA(code('reserved')));
    await transact(a, '1');
    expect((await w(a)).balance, Money.parse('-11', ils));
    expect((await g(id)).events, isEmpty);
  });
  test('FX reversal protects destination currency reservations and releases preserve source fees', () async {
    final a = await wallet(), b = await wallet(balance: '0', currency: usd);
    final transferId = await transfers.create(
      WalletOperation.generate(),
      TransferDraft(
        sourceId: a,
        destinationId: b,
        amount: Money.parse('400', ils),
        fee: Money.parse('2', ils),
        rate: ExchangeRate.parse('0.25'),
      ),
      await revs(),
    );
    final id = await goal(currency: usd);
    await allocate(id, b, '100', currency: usd);
    await expectLater(
      transfers.cancel(WalletOperation.generate(), transferId, 0, await revs()),
      throwsA(code('reserved')),
    );
    expect((await w(a)).balance, Money.parse('598', ils));
    expect((await w(b)).balance, Money.parse('100', usd));
    await allocate(id, b, '0', currency: usd);
    await transfers.cancel(
      WalletOperation.generate(),
      transferId,
      0,
      await revs(),
    );
    expect((await w(a)).balance, Money.parse('1000', ils));
    expect((await w(b)).balance, Money.parse('0', usd));
    expect((await tx.load()).single.deleted, isTrue);
  });
  test('goal create and metadata edit retry with stable ids without duplicate entities or revisions', () async {
    final create = WalletOperation.generate(), initial = draft();
    final id = await goals.create(create, initial);
    await goals.create(create, initial);
    final edit = WalletOperation.generate(), next = draft(name: 'Updated');
    await goals.edit(edit, id, 0, next);
    await goals.edit(edit, id, 0, next);
    expect((await goals.load()).length, 1);
    expect((await g(id)).goal.revision, 1);
    await expectLater(
      goals.create(create, draft(name: 'Different')),
      throwsStateError,
    );
  });
  test('calendar remaining days is correct across DST, leap years and overdue dates', () async {
    final id = await goals.create(
          WalletOperation.generate(),
          draft(date: '2028-03-01'),
        ),
        s = await g(id);
    expect(s.daysRemaining(DateTime(2028, 2, 28, 23)), 2);
    expect(s.daysRemaining(DateTime(2028, 3, 1)), 0);
    expect(s.daysRemaining(DateTime(2028, 3, 2)), -1);
  });
}

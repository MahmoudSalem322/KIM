import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository transactions;
  final ils = Currency('ILS', 2);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim-transactions-');
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
    wallets = LocalWalletRepository(db);
    transactions = LocalTransactionRepository(db);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<String> wallet({
    String name = 'Cash',
    String opening = '100.00',
    Currency? currency,
  }) => wallets.create(
    WalletOperation.generate(),
    WalletDraft(
      name: name,
      color: 'emerald',
      icon: 'wallet',
      type: 'cash',
      currency: currency ?? ils,
    ),
    Money.parse(opening, currency ?? ils),
  );
  Future<Map<String, int>> revisions() async => {
    for (final w in await wallets.load()) w.wallet.id: w.wallet.revision,
  };
  TransactionDraft draft(
    String id,
    String amount, {
    TransactionKind kind = TransactionKind.expense,
    String date = '2020-02-29',
    Currency? currency,
    String notes = 'Lunch',
  }) => TransactionDraft(
    walletId: id,
    kind: kind,
    amount: Money.parse(amount, currency ?? ils),
    category: kind == TransactionKind.income ? 'salary' : 'food',
    date: date,
    notes: notes,
  );
  Future<String> balance(String id) async => (await wallets.load())
      .singleWhere((w) => w.wallet.id == id)
      .balance
      .decimal;

  test(
    'income expense and replay persist exact Arabic decimals after reopen',
    () async {
      final id = await wallet();
      final op = WalletOperation.generate(),
          payload = draft(id, '١٠٫٢٥', kind: TransactionKind.income);
      final rev = await revisions();
      final tid = await transactions.create(op, payload, rev);
      await transactions.create(op, payload, rev);
      await transactions.create(
        WalletOperation.generate(),
        draft(id, '3.10'),
        await revisions(),
      );
      expect(await balance(id), '107.15');
      expect((await transactions.load()).length, 2);
      expect((await wallets.load()).single.entries.length, 3);
      await db.close();
      db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
      wallets = LocalWalletRepository(db);
      transactions = LocalTransactionRepository(db);
      expect(await balance(id), '107.15');
      expect((await transactions.load()).any((t) => t.id == tid), true);
    },
  );
  test('edit amount kind and past date compensates previous effect', () async {
    final id = await wallet();
    final tid = await transactions.create(
      WalletOperation.generate(),
      draft(id, '12.35'),
      await revisions(),
    );
    final original = (await wallets.load()).single.entries.last;
    await transactions.edit(
      WalletOperation.generate(),
      tid,
      0,
      draft(id, '8.15', kind: TransactionKind.income, date: '1999-01-01'),
      await revisions(),
    );
    expect(await balance(id), '108.15');
    final history = (await wallets.load()).single.entries;
    expect(history.length, 4);
    expect(history[1].delta, original.delta);
    expect(history[2].delta.decimal, '12.35');
    expect(history[3].delta.decimal, '8.15');
    final t = (await transactions.load()).single;
    expect(t.date, '1999-01-01');
    expect(t.revision, 1);
  });
  test('cancellation reverses once keeps evidence and is idempotent', () async {
    final id = await wallet();
    final tid = await transactions.create(
      WalletOperation.generate(),
      draft(id, '2.55'),
      await revisions(),
    );
    final op = WalletOperation.generate(), rev = await revisions();
    await transactions.delete(op, tid, 0, rev);
    await transactions.delete(op, tid, 0, rev);
    expect(await balance(id), '100.00');
    expect((await transactions.load()).single.deleted, true);
    await expectLater(
      transactions.delete(
        WalletOperation.generate(),
        tid,
        1,
        await revisions(),
      ),
      throwsA(isA<WalletFailure>()),
    );
    expect((await wallets.load()).single.entries.length, 3);
  });
  test('editing old operation after settlement adjusts net effect without rewriting settlement', () async {
    final id = await wallet();
    final tid = await transactions.create(
      WalletOperation.generate(),
      draft(id, '10.00'),
      await revisions(),
    );
    var w = (await wallets.load()).single;
    await wallets.adjust(
      WalletOperation.generate(),
      id,
      w.wallet.revision,
      Money.parse('95.00', ils),
      'Count',
    );
    await transactions.edit(
      WalletOperation.generate(),
      tid,
      0,
      draft(id, '20.00', date: '1900-01-01'),
      await revisions(),
    );
    expect(await balance(id), '85.00');
    w = (await wallets.load()).single;
    expect(w.entries[2].after.decimal, '95.00');
    await transactions.delete(
      WalletOperation.generate(),
      tid,
      1,
      await revisions(),
    );
    expect(await balance(id), '105.00');
  });
  test('wallet reassignment reverses and applies atomically including currency change', () async {
    final a = await wallet();
    final jod = Currency('JOD', 3);
    final b = await wallet(name: 'Bank', opening: '50.000', currency: jod);
    final tid = await transactions.create(
      WalletOperation.generate(),
      draft(a, '3.45'),
      await revisions(),
    );
    await expectLater(
      transactions.edit(
        WalletOperation.generate(),
        tid,
        0,
        draft(b, '3.45'),
        await revisions(),
      ),
      throwsA(isA<WalletFailure>()),
    );
    expect(await balance(a), '96.55');
    expect(await balance(b), '50.000');
    await transactions.edit(
      WalletOperation.generate(),
      tid,
      0,
      draft(b, '1.234', currency: jod),
      await revisions(),
    );
    expect(await balance(a), '100.00');
    expect(await balance(b), '48.766');
  });
  test('stale writes and archived target rollback all effects', () async {
    final a = await wallet();
    final b = await wallet(name: 'Bank');
    final tid = await transactions.create(
      WalletOperation.generate(),
      draft(a, '2.00'),
      await revisions(),
    );
    final stale = await revisions();
    await wallets.setArchived(WalletOperation.generate(), b, stale[b]!, true);
    await expectLater(
      transactions.edit(
        WalletOperation.generate(),
        tid,
        0,
        draft(b, '5.00'),
        await revisions(),
      ),
      throwsA(isA<WalletFailure>()),
    );
    expect(await balance(a), '98.00');
    expect((await transactions.load()).single.revision, 0);
    await transactions.edit(
      WalletOperation.generate(),
      tid,
      0,
      draft(a, '5.00'),
      await revisions(),
    );
    await expectLater(
      transactions.delete(WalletOperation.generate(), tid, 0, stale),
      throwsA(isA<WalletFailure>()),
    );
    expect(await balance(a), '95.00');
  });
  test('simultaneous saves with one command never duplicate balance', () async {
    final id = await wallet();
    final op = WalletOperation.generate(), rev = await revisions();
    await Future.wait([
      transactions.create(op, draft(id, '0.01'), rev),
      transactions.create(op, draft(id, '0.01'), rev),
    ]);
    expect(await balance(id), '99.99');
    expect((await transactions.load()).length, 1);
    await expectLater(
      transactions.create(op, draft(id, '0.02'), rev),
      throwsStateError,
    );
  });
  test('invalid amounts categories dates and notes do not write', () async {
    final id = await wallet();
    for (final value in ['0.00', '-1.00']) {
      await expectLater(
        transactions.create(
          WalletOperation.generate(),
          draft(id, value),
          await revisions(),
        ),
        throwsA(isA<WalletFailure>()),
      );
    }
    for (final date in ['2023-02-29', '2020-13-01', '1899-01-01']) {
      await expectLater(
        transactions.create(
          WalletOperation.generate(),
          draft(id, '1.00', date: date),
          await revisions(),
        ),
        throwsA(isA<WalletFailure>()),
      );
    }
    final invalid = TransactionDraft(
      walletId: id,
      kind: TransactionKind.expense,
      amount: Money.parse('1.00', ils),
      category: 'salary',
      date: '2020-01-01',
      notes: '',
    );
    await expectLater(
      transactions.create(
        WalletOperation.generate(),
        invalid,
        await revisions(),
      ),
      throwsA(isA<WalletFailure>()),
    );
    await expectLater(
      transactions.create(
        WalletOperation.generate(),
        draft(id, '1.00', notes: 'x' * 1001),
        await revisions(),
      ),
      throwsA(isA<WalletFailure>()),
    );
    expect(await balance(id), '100.00');
    expect(await transactions.load(), isEmpty);
  });
  test('huge amounts and six decimals remain exact on edits', () async {
    final c = Currency('ABC', 6);
    final id = await wallet(
      opening: '900719925474099312345.123456',
      currency: c,
    );
    final tid = await transactions.create(
      WalletOperation.generate(),
      draft(id, '0.000001', currency: c),
      await revisions(),
    );
    expect(await balance(id), '900719925474099312345.123455');
    await transactions.edit(
      WalletOperation.generate(),
      tid,
      0,
      draft(id, '0.000002', currency: c),
      await revisions(),
    );
    expect(await balance(id), '900719925474099312345.123454');
  });
  test(
    'query combines search type wallet category dates and cancelled status',
    () async {
      final id = await wallet();
      await transactions.create(
        WalletOperation.generate(),
        draft(id, '2.00', notes: 'Coffee', date: '2020-01-01'),
        await revisions(),
      );
      await transactions.create(
        WalletOperation.generate(),
        draft(
          id,
          '7.00',
          kind: TransactionKind.income,
          notes: 'Pay',
          date: '2021-01-01',
        ),
        await revisions(),
      );
      final all = await transactions.load();
      expect(all.first.date, '2021-01-01');
      expect(
        all
            .where(
              (t) => TransactionQuery(
                search: 'coFFee',
                kind: TransactionKind.expense,
                walletId: id,
                category: 'food',
                from: '2020-01-01',
                to: '2020-12-31',
              ).matches(t),
            )
            .length,
        1,
      );
      expect(
        all
            .where(
              (t) =>
                  const TransactionQuery(search: 'Bank')
                      .matches(t, walletName: 'Bank'),
            )
            .length,
        2,
      );
      expect(
        all.where((t) => const TransactionQuery(from: '2022-01-01').matches(t)),
        isEmpty,
      );
      await transactions.delete(
        WalletOperation.generate(),
        all.last.id,
        0,
        await revisions(),
      );
      final cancelled = (await transactions.load()).last;
      expect(const TransactionQuery().matches(cancelled), false);
      expect(const TransactionQuery(deleted: true).matches(cancelled), true);
    },
  );
  test('schema 3 migration preserves existing wallets ledger preferences and receipts', () async {
    final id = await wallet();
    final opening = (await wallets.load()).single.entries.single.operationId;
    await db.close();
    final legacy = await databaseFactoryIo.openDatabase(
      '${dir.path}/data.db',
      version: 3,
      onVersionChanged: (_, oldVersion, newVersion) async {},
    );
    await AppDatabase.settings.record('preferences').put(legacy, {
      'languageCode': 'en',
      'theme': 'dark',
    });
    await legacy.close();
    final migrated = await AppDatabase.open(
      databaseFactoryIo,
      '${dir.path}/data.db',
    );
    expect(
      (await AppDatabase.settings
          .record('preferences')
          .get(migrated.database))!['theme'],
      'dark',
    );
    expect(await LocalTransactionRepository(migrated).load(), isEmpty);
    final saved = (await LocalWalletRepository(migrated).load()).single;
    expect(saved.wallet.id, id);
    expect(saved.balance.decimal, '100.00');
    expect(saved.entries.single.operationId, opening);
    expect(
      await stringMapStoreFactory
          .store('operation_receipts')
          .record(opening)
          .exists(migrated.database),
      true,
    );
    await migrated.close();
  });
  test(
    'tampered transaction amount cannot create an incorrect reversal',
    () async {
      final id = await wallet();
      final tid = await transactions.create(
        WalletOperation.generate(),
        draft(id, '2.00'),
        await revisions(),
      );
      final row = (await LocalTransactionRepository.store
          .record(tid)
          .get(db.database))!;
      await LocalTransactionRepository.store.record(tid).put(db.database, {
        ...row,
        'amount': Money.parse('20.00', ils).toJson(),
      });
      await expectLater(
        transactions.delete(
          WalletOperation.generate(),
          tid,
          0,
          await revisions(),
        ),
        throwsA(isA<WalletFailure>()),
      );
      expect(await balance(id), '98.00');
    },
  );
}

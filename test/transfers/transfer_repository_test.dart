import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:uuid/uuid.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transfers/domain/exchange_rate.dart';
import 'package:kim/features/transfers/domain/wallet_transfer.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';

void main() {
  final ils = Currency('ILS', 2), usd = Currency('USD', 2);
  late Directory dir;
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository transactions;
  late LocalTransferRepository transfers;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim-transfers-');
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
    wallets = LocalWalletRepository(db);
    transactions = LocalTransactionRepository(db);
    transfers = LocalTransferRepository(db);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<String> wallet({Currency? currency, String opening = '100.00'}) =>
      wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Cash',
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
  Future<String> balance(String id) async => (await wallets.load())
      .singleWhere((w) => w.wallet.id == id)
      .balance
      .decimal;
  TransferDraft draft(
    String from,
    String to, {
    String amount = '10.25',
    String fee = '0',
    String rate = '1',
    Currency? currency,
  }) => TransferDraft(
    sourceId: from,
    destinationId: to,
    amount: Money.parse(amount, currency ?? ils),
    fee: Money.parse(fee, currency ?? ils),
    rate: ExchangeRate.parse(rate),
    notes: 'Savings',
  );
  Future<void> expense(String id, String amount) async {
    await transactions.create(
      WalletOperation.generate(),
      TransactionDraft(
        walletId: id,
        kind: TransactionKind.expense,
        amount: Money.parse(amount, ils),
        category: 'food',
        date: '2020-02-29',
      ),
      await revisions(),
    );
  }

  test('rational Arabic FX half-up works across scales and huge integers', () {
    expect(
      ExchangeRate.parse('٠٫٥').convert(Money.parse('0.01', ils), usd).decimal,
      '0.01',
    );
    expect(ExchangeRate.parse('1.234567890123').decimal, '1.234567890123');
    expect(ExchangeRate.parse('1.000').decimal, '1');
    expect(
      ExchangeRate.parse('1')
          .convert(
            Money.parse('12345678901234567890.123456', Currency('USD', 6)),
            Currency('USD', 3),
          )
          .decimal,
      '12345678901234567890.123',
    );
    for (final invalid in ['0', '-1', '1e3', '1,2', '0.1234567890123']) {
      expect(() => ExchangeRate.parse(invalid), throwsFormatException);
    }
  });
  test(
    'both legs and only fee expense persist exactly after reopen and replay',
    () async {
      final a = await wallet(), b = await wallet(currency: usd, opening: '0');
      final op = WalletOperation.generate(),
          d = draft(a, b, amount: '20.10', fee: '0.35', rate: '0.275');
      final rev = await revisions();
      final id = await transfers.create(op, d, rev);
      await transfers.create(op, d, rev);
      expect(await balance(a), '79.55');
      expect(await balance(b), '5.53');
      final fees = await transactions.load();
      expect(fees.length, 1);
      expect(fees.single.draft.kind, TransactionKind.expense);
      expect(fees.single.draft.amount.decimal, '0.35');
      expect(fees.single.linkedTransferId, id);
      expect(
        (await wallets.load())
            .expand((w) => w.entries)
            .where((e) => e.transferId == id)
            .length,
        3,
      );
      await db.close();
      db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
      wallets = LocalWalletRepository(db);
      transfers = LocalTransferRepository(db);
      transactions = LocalTransactionRepository(db);
      expect((await transfers.load()).single.received.decimal, '5.53');
      expect((await transfers.load()).single.draft.rate.decimal, '0.275');
      expect(await balance(a), '79.55');
    },
  );
  test('edit both wallets and FX reverses old legs and fee then cancel replays once', () async {
    final a = await wallet(),
        b = await wallet(opening: '0'),
        c = await wallet(currency: usd, opening: '0');
    final id = await transfers.create(
      WalletOperation.generate(),
      draft(a, b, fee: '1'),
      await revisions(),
    );
    await transfers.edit(
      WalletOperation.generate(),
      id,
      0,
      draft(a, c, amount: '20', fee: '2', rate: '0.5'),
      await revisions(),
    );
    expect(await balance(a), '78.00');
    expect(await balance(b), '0.00');
    expect(await balance(c), '10.00');
    expect((await transactions.load()).single.draft.amount.decimal, '2.00');
    final op = WalletOperation.generate(), rev = await revisions();
    await transfers.cancel(op, id, 1, rev);
    await transfers.cancel(op, id, 1, rev);
    expect(await balance(a), '100.00');
    expect(await balance(c), '0.00');
    expect((await transfers.load()).single.cancelled, true);
    expect((await transactions.load()).single.deleted, true);
  });
  test('insufficient source including fee rejects all effects', () async {
    final a = await wallet(opening: '10'), b = await wallet();
    await expectLater(
      transfers.create(
        WalletOperation.generate(),
        draft(a, b, amount: '10', fee: '0.01'),
        await revisions(),
      ),
      throwsA(
        isA<WalletFailure>().having((e) => e.code, 'code', 'insufficient'),
      ),
    );
    expect(await balance(a), '10.00');
    expect(await transfers.load(), isEmpty);
    expect(await transactions.load(), isEmpty);
  });
  test('spent destination blocks cancellation atomically', () async {
    final a = await wallet(), b = await wallet(opening: '0');
    final id = await transfers.create(
      WalletOperation.generate(),
      draft(a, b, amount: '10', fee: '1'),
      await revisions(),
    );
    await expense(b, '9');
    await expectLater(
      transfers.cancel(WalletOperation.generate(), id, 0, await revisions()),
      throwsA(
        isA<WalletFailure>().having((e) => e.code, 'code', 'insufficient'),
      ),
    );
    expect(await balance(a), '89.00');
    expect(await balance(b), '1.00');
    expect((await transfers.load()).single.cancelled, false);
  });
  test('net edit allows retained credit after spending but rejects excessive refund', () async {
    final a = await wallet(), b = await wallet(opening: '0');
    final id = await transfers.create(
      WalletOperation.generate(),
      draft(a, b, amount: '10'),
      await revisions(),
    );
    await expense(b, '9');
    await transfers.edit(
      WalletOperation.generate(),
      id,
      0,
      draft(a, b, amount: '9'),
      await revisions(),
    );
    expect(await balance(b), '0.00');
    expect(await balance(a), '91.00');
    await expectLater(
      transfers.edit(
        WalletOperation.generate(),
        id,
        1,
        draft(a, b, amount: '8'),
        await revisions(),
      ),
      throwsA(isA<WalletFailure>()),
    );
    expect(await balance(a), '91.00');
  });
  test(
    'interruption after source write rolls back and same command can retry',
    () async {
      final a = await wallet(),
          b = await wallet(opening: '0'),
          op = WalletOperation.generate();
      // A reserved destination entry ID forces failure after the source leg write.
      final collision = const Uuid().v5(op.id.value, 'new-in');
      await LocalWalletRepository.entries.record(collision).put(db.database, {
        'reserved': true,
      });
      final rev = {a: 0, b: 0}, d = draft(a, b, fee: '1');
      await expectLater(
        transfers.create(op, d, rev),
        throwsA(isA<WalletFailure>()),
      );
      expect(
        await LocalWalletRepository.wallets.record(a).get(db.database),
        containsPair('revision', 0),
      );
      expect(await LocalTransferRepository.store.count(db.database), 0);
      expect(await LocalTransactionRepository.store.count(db.database), 0);
      expect(await LocalWalletRepository.entries.count(db.database), 3);
      await LocalWalletRepository.entries.record(collision).delete(db.database);
      await transfers.create(op, d, rev);
      expect(await balance(a), '88.75');
      expect(await balance(b), '10.25');
    },
  );
  test('duplicate concurrent commands and mismatched UUID reuse never double transfer', () async {
    final a = await wallet(),
        b = await wallet(opening: '0'),
        op = WalletOperation.generate();
    final rev = await revisions(), d = draft(a, b);
    await Future.wait([
      transfers.create(op, d, rev),
      transfers.create(op, d, rev),
    ]);
    expect(await balance(b), '10.25');
    expect((await transfers.load()).length, 1);
    await expectLater(
      transfers.create(op, draft(a, b, amount: '5'), rev),
      throwsStateError,
    );
  });
  test(
    'stale archived same wallet currency and rounded zero fail safely',
    () async {
      final a = await wallet(),
          b = await wallet(currency: usd),
          rev = await revisions();
      await wallets.setHidden(WalletOperation.generate(), a, 0, true);
      await expectLater(
        transfers.create(WalletOperation.generate(), draft(a, b), rev),
        throwsA(isA<WalletFailure>()),
      );
      await wallets.setArchived(WalletOperation.generate(), b, 0, true);
      await expectLater(
        transfers.create(
          WalletOperation.generate(),
          draft(a, b),
          await revisions(),
        ),
        throwsA(isA<WalletFailure>()),
      );
      await expectLater(
        transfers.create(
          WalletOperation.generate(),
          draft(a, a),
          await revisions(),
        ),
        throwsA(isA<WalletFailure>()),
      );
      await wallets.setArchived(WalletOperation.generate(), b, 1, false);
      await expectLater(
        transfers.create(
          WalletOperation.generate(),
          draft(a, b, amount: '0.01', rate: '0.001'),
          await revisions(),
        ),
        throwsA(isA<WalletFailure>()),
      );
      expect(await transfers.load(), isEmpty);
    },
  );
  test(
    'fees cannot be edited or deleted through regular transactions',
    () async {
      final a = await wallet(), b = await wallet();
      await transfers.create(
        WalletOperation.generate(),
        draft(a, b, fee: '1'),
        await revisions(),
      );
      final fee = (await transactions.load()).single;
      await expectLater(
        transactions.delete(
          WalletOperation.generate(),
          fee.id,
          fee.revision,
          await revisions(),
        ),
        throwsA(
          isA<WalletFailure>().having((e) => e.code, 'code', 'linkedTransfer'),
        ),
      );
      await expectLater(
        transactions.edit(
          WalletOperation.generate(),
          fee.id,
          fee.revision,
          fee.draft,
          await revisions(),
        ),
        throwsA(isA<WalletFailure>()),
      );
      expect(await balance(a), '88.75');
    },
  );
  test('fee zero positive zero positive keeps one auditable expense', () async {
    final a = await wallet(), b = await wallet();
    final id = await transfers.create(
      WalletOperation.generate(),
      draft(a, b),
      await revisions(),
    );
    expect(await transactions.load(), isEmpty);
    for (final fee in ['1', '0', '2']) {
      final t = (await transfers.load()).single;
      await transfers.edit(
        WalletOperation.generate(),
        id,
        t.revision,
        draft(a, b, fee: fee),
        await revisions(),
      );
    }
    expect((await transactions.load()).length, 1);
    expect((await transactions.load()).single.draft.amount.decimal, '2.00');
    expect(await balance(a), '87.75');
  });
  test('saved rate or amounts tampering rejects load and reversal', () async {
    final a = await wallet(), b = await wallet();
    final id = await transfers.create(
      WalletOperation.generate(),
      draft(a, b),
      await revisions(),
    );
    final value = (await LocalTransferRepository.store
        .record(id)
        .get(db.database))!;
    await LocalTransferRepository.store.record(id).put(db.database, {
      ...value,
      'received': Money.parse('999', ils).toJson(),
    });
    await expectLater(transfers.load(), throwsA(isA<WalletFailure>()));
    await expectLater(
      transfers.cancel(WalletOperation.generate(), id, 0, await revisions()),
      throwsA(isA<WalletFailure>()),
    );
    expect(await balance(a), '89.75');
  });
  test(
    'same currency code differing scale uses rate one and documented rounding',
    () async {
      final a = await wallet(),
          b = await wallet(currency: Currency('ILS', 0), opening: '0');
      await expectLater(
        transfers.create(
          WalletOperation.generate(),
          draft(a, b, rate: '2'),
          await revisions(),
        ),
        throwsA(isA<WalletFailure>()),
      );
      await transfers.create(
        WalletOperation.generate(),
        draft(a, b, amount: '10.50'),
        await revisions(),
      );
      expect(await balance(a), '89.50');
      expect(await balance(b), '11');
    },
  );
  test(
    'swapping source and destination carries fees to the new source',
    () async {
      final a = await wallet(), b = await wallet(opening: '20');
      final id = await transfers.create(
        WalletOperation.generate(),
        draft(a, b, amount: '10', fee: '1'),
        await revisions(),
      );
      await transfers.edit(
        WalletOperation.generate(),
        id,
        0,
        draft(b, a, amount: '5', fee: '1'),
        await revisions(),
      );
      expect(await balance(a), '105.00');
      expect(await balance(b), '14.00');
      expect((await transactions.load()).single.walletId, b);
      await transfers.cancel(
        WalletOperation.generate(),
        id,
        1,
        await revisions(),
      );
      expect(await balance(a), '100.00');
      expect(await balance(b), '20.00');
    },
  );
  test(
    'negative destination can receive but negative source cannot send',
    () async {
      final a = await wallet(), b = await wallet(opening: '-20');
      await transfers.create(
        WalletOperation.generate(),
        draft(a, b, amount: '5'),
        await revisions(),
      );
      expect(await balance(b), '-15.00');
      await expectLater(
        transfers.create(
          WalletOperation.generate(),
          draft(b, a, amount: '1'),
          await revisions(),
        ),
        throwsA(isA<WalletFailure>()),
      );
    },
  );
  test('schema four migration preserves transactions wallets settings and receipts', () async {
    final a = await wallet(), b = await wallet();
    await expense(a, '1.25');
    final tid = (await transactions.load()).single.id;
    final ledger = (await wallets.load())
        .expand((w) => w.entries)
        .map((e) => e.operationId)
        .toList();
    await db.close();
    final legacy = await databaseFactoryIo.openDatabase(
      '${dir.path}/data.db',
      version: 4,
      onVersionChanged: (_, oldVersion, newVersion) async {},
    );
    await AppDatabase.settings.record('preferences').put(legacy, {
      'languageCode': 'en',
      'theme': 'dark',
    });
    await stringMapStoreFactory
        .store('schema')
        .record('transfers')
        .delete(legacy);
    await legacy.close();
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
    wallets = LocalWalletRepository(db);
    transactions = LocalTransactionRepository(db);
    transfers = LocalTransferRepository(db);
    expect(db.database.version, 5);
    expect((await transactions.load()).single.id, tid);
    expect(await balance(a), '98.75');
    expect(await balance(b), '100.00');
    expect(
      (await AppDatabase.settings
          .record('preferences')
          .get(db.database))!['theme'],
      'dark',
    );
    for (final id in ledger) {
      expect(
        await stringMapStoreFactory
            .store('operation_receipts')
            .record(id)
            .exists(db.database),
        true,
      );
    }
    await transfers.create(
      WalletOperation.generate(),
      draft(a, b),
      await revisions(),
    );
    expect(await balance(a), '88.50');
  });
}

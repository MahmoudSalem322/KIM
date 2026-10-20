import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/reports/domain/exchange_book.dart';
import 'package:kim/features/reports/domain/financial_report.dart';
import 'package:kim/features/reports/data/local_exchange_repository.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/domain/wallet_transfer.dart';
import 'package:kim/features/transfers/domain/exchange_rate.dart';
import 'package:kim/features/debts/data/local_debt_repository.dart';
import 'package:kim/features/debts/domain/debt.dart';

void main() {
  final ils = Currency('ILS', 2), usd = Currency('USD', 2);
  late Directory dir;
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository transactions;
  late LocalTransferRepository transfers;
  late LocalDebtRepository debts;
  late LocalExchangeRepository exchange;
  Future<void> open() async {
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
    wallets = LocalWalletRepository(db);
    transactions = LocalTransactionRepository(db);
    transfers = LocalTransferRepository(db);
    debts = LocalDebtRepository(db);
    exchange = LocalExchangeRepository(db);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim-reports-');
    await open();
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  ManualRate rate({String value = '3.5'}) => ManualRate(
    from: usd,
    to: ils,
    decimal: value,
    source: 'User bank receipt',
    asOf: '2026-10-20',
    updatedAt: DateTime.utc(2026, 10, 20),
  );
  ExchangeBook book() => ExchangeBook(currency: ils, rates: [rate()]);
  Future<String> wallet(Currency c) => wallets.create(
    WalletOperation.generate(),
    WalletDraft(
      name: c.code,
      color: 'blue',
      icon: 'cash',
      type: 'cash',
      currency: c,
    ),
    Money.parse('1000', c),
  );
  Future<Map<String, int>> revisions() async => {
    for (final w in await wallets.load()) w.wallet.id: w.wallet.revision,
  };
  Future<String> transaction(
    String wid,
    Currency c,
    String value, {
    TransactionKind kind = TransactionKind.expense,
    String date = '2026-10-20',
  }) async => transactions.create(
    WalletOperation.generate(),
    TransactionDraft(
      walletId: wid,
      kind: kind,
      amount: Money.parse(value, c),
      category: kind == TransactionKind.expense ? 'food' : 'salary',
      date: date,
    ),
    await revisions(),
  );
  Future<ReportResult> report({
    ExchangeBook? rates,
    String? walletId,
    String? category,
  }) async => ReportResult.calculate(
    filter: ReportFilter(
      from: '2026-10-01',
      to: '2026-10-31',
      walletId: walletId,
      category: category,
    ),
    book: rates ?? book(),
    wallets: await wallets.load(),
    transactions: await transactions.load(),
    transfers: await transfers.load(),
    debts: await debts.load(),
  );

  test(
    'exact signed conversion, inverse and scale rounding beyond safe integers',
    () {
      final b = book();
      expect(
        b.convert(Money.parse('9007199254740993.25', usd))!.amount.decimal,
        '31525197391593476.38',
      );
      expect(b.convert(Money.parse('-0.01', usd))!.amount.decimal, '-0.04');
      final inverse = ExchangeBook(currency: usd, rates: [rate()]);
      expect(inverse.convert(Money.parse('3.50', ils))!.amount.decimal, '1.00');
      expect(inverse.convert(Money.parse('3.50', ils))!.inverse, true);
      final jpy = Currency('JPY', 0);
      expect(
        ExchangeBook(
          currency: jpy,
          rates: [
            ManualRate(
              from: usd,
              to: jpy,
              decimal: '150.5',
              source: 'Manual',
              asOf: '2026-10-20',
              updatedAt: DateTime.utc(2026),
            ),
          ],
        ).convert(Money.parse('0.01', usd))!.amount.decimal,
        '2',
      );
    },
  );
  test(
    'quotes reject zero, duplicate inverse pairs and undocumented sources',
    () {
      expect(() => rate(value: '0'), throwsFormatException);
      expect(
        () => ManualRate(
          from: usd,
          to: ils,
          decimal: '3',
          source: ' ',
          asOf: '2026-10-20',
          updatedAt: DateTime.now(),
        ),
        throwsFormatException,
      );
      expect(
        () => ExchangeBook(
          currency: ils,
          rates: [
            rate(),
            ManualRate(
              from: ils,
              to: usd,
              decimal: '0.3',
              source: 'Manual',
              asOf: '2026-10-20',
              updatedAt: DateTime.now(),
            ),
          ],
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'persist display settings, replay once, reject stale revisions and reopen',
    () async {
      final op = WalletOperation.generate();
      final rates = [rate()];
      await exchange.save(op, 0, usd, rates);
      await exchange.save(op, 0, usd, rates);
      expect((await exchange.load()).revision, 1);
      await expectLater(
        exchange.save(WalletOperation.generate(), 0, ils, rates),
        throwsA(isA<WalletFailure>()),
      );
      await db.close();
      await open();
      final loaded = await exchange.load();
      expect(loaded.currency, usd);
      expect(loaded.rates.single.source, 'User bank receipt');
    },
  );
  test('real transactions use exact currencies and display switch never mutates originals', () async {
    final a = await wallet(ils), b = await wallet(usd);
    await transaction(a, ils, '100', kind: TransactionKind.income);
    await transaction(b, usd, '10');
    final r = await report();
    expect(r.income.decimal, '100.00');
    expect(r.expense.decimal, '35.00');
    expect(r.cashFlow.decimal, '65.00');
    final before = (await transactions.load())
        .map((t) => t.draft.toJson())
        .toList();
    await report(
      rates: ExchangeBook(currency: usd, rates: [rate()]),
    );
    expect(
      (await transactions.load()).map((t) => t.draft.toJson()).toList(),
      before,
    );
    expect(r.categories['food']!.decimal, '35.00');
    expect(
      r.buckets.fold(BigInt.zero, (s, b) => s + b.expense.minorUnits),
      r.expense.minorUnits,
    );
  });
  test(
    'missing quote excludes only unconvertible rows and marks incomplete',
    () async {
      final a = await wallet(usd);
      await transaction(a, usd, '10');
      final r = await report(
        rates: ExchangeBook(currency: ils, rates: []),
      );
      expect(r.complete, false);
      expect(r.missingCurrencies, {usd});
      expect(r.rows.single.converted, null);
      expect(r.expense.decimal, '0.00');
    },
  );
  test(
    'transfer principal excluded from income/expense; fee counted exactly once',
    () async {
      final a = await wallet(ils), b = await wallet(usd);
      final op = WalletOperation(
        WalletOperation.generate().id,
        DateTime(2026, 10, 20, 12),
      );
      await transfers.create(
        op,
        TransferDraft(
          sourceId: a,
          destinationId: b,
          amount: Money.parse('350', ils),
          fee: Money.parse('2', ils),
          rate: ExchangeRate.parse('0.285714285714'),
        ),
        await revisions(),
      );
      final r = await report();
      expect(r.income.decimal, '0.00');
      expect(r.expense.decimal, '2.00');
      expect(r.transferNet.decimal, '0.00');
      expect(r.cashFlow.decimal, '-2.00');
      final selected = await report(walletId: a);
      expect(selected.transferNet.decimal, '-350.00');
      expect(selected.cashFlow.decimal, '-352.00');
      final category = await report(category: 'transferFee');
      expect(category.rows.length, 1);
      expect(category.cashFlow.decimal, '-2.00');
    },
  );
  test('debt administrative record has no movement; actual payments change cash only', () async {
    final a = await wallet(ils);
    final id = await debts.create(
      WalletOperation.generate(),
      DebtDraft(
        direction: DebtDirection.borrowed,
        person: 'Ahmad',
        principal: Money.parse('100', ils),
        dueOn: '2026-11-01',
      ),
    );
    expect((await report()).cashFlow.decimal, '0.00');
    var d = (await debts.load()).single;
    await debts.record(
      WalletOperation.generate(),
      id,
      d.debt.revision,
      DebtCashDraft(
        kind: DebtEventKind.principal,
        walletId: a,
        amount: Money.parse('100', ils),
        date: '2026-10-20',
      ),
      await revisions(),
    );
    d = (await debts.load()).single;
    await debts.record(
      WalletOperation.generate(),
      id,
      d.debt.revision,
      DebtCashDraft(
        kind: DebtEventKind.payment,
        walletId: a,
        amount: Money.parse('25', ils),
        date: '2026-10-20',
      ),
      await revisions(),
    );
    final r = await report();
    expect(r.income.decimal, '0.00');
    expect(r.expense.decimal, '0.00');
    expect(r.debtNet.decimal, '75.00');
    expect((await report(category: 'food')).debtNet.decimal, '0.00');
  });
  test('edit/delete current effective records avoid double counting reversal ledger', () async {
    final a = await wallet(ils);
    final id = await transaction(a, ils, '20');
    var t = (await transactions.load()).single;
    await transactions.edit(
      WalletOperation.generate(),
      id,
      t.revision,
      TransactionDraft(
        walletId: a,
        kind: TransactionKind.expense,
        amount: Money.parse('7', ils),
        category: 'food',
        date: '2026-10-20',
      ),
      await revisions(),
    );
    expect((await report()).expense.decimal, '7.00');
    t = (await transactions.load()).single;
    await transactions.delete(
      WalletOperation.generate(),
      id,
      t.revision,
      await revisions(),
    );
    expect((await report()).expense.decimal, '0.00');
  });
  test('comparison uses equal calendar days; previous hidden currency stays private/incomplete', () async {
    final a = await wallet(usd);
    await transaction(a, usd, '10', date: '2026-09-30');
    final w = (await wallets.load()).single;
    await wallets.setHidden(
      WalletOperation.generate(),
      a,
      w.wallet.revision,
      true,
    );
    final r = await report(
      rates: ExchangeBook(currency: ils, rates: []),
    );
    expect(r.filter.previous.from, '2026-08-31');
    expect(r.filter.previous.to, '2026-09-30');
    expect(r.concealed, true);
    expect(r.previous.complete, false);
    expect(r.complete, false);
  });
  test(
    'internal exchange valuation residual stays separate from cash flow',
    () async {
      final a = await wallet(usd), b = await wallet(ils);
      final id = await transfers.create(
        WalletOperation(
          WalletOperation.generate().id,
          DateTime(2026, 10, 20, 12),
        ),
        TransferDraft(
          sourceId: a,
          destinationId: b,
          amount: Money.parse('10', usd),
          fee: Money.parse('1', usd),
          rate: ExchangeRate.parse('3.6'),
        ),
        await revisions(),
      );
      final r = await report();
      expect(r.transferNet.decimal, '0.00');
      expect(r.totals.transferValuationDifference.decimal, '1.00');
      expect(r.expense.decimal, '3.50');
      expect(r.cashFlow.decimal, '-3.50');
      expect((await report(walletId: a)).cashFlow.decimal, '-38.50');
      expect((await report(walletId: b)).cashFlow.decimal, '36.00');
      final t = (await transfers.load()).single;
      await transfers.cancel(
        WalletOperation.generate(),
        id,
        t.revision,
        await revisions(),
      );
      expect((await report()).rows, isEmpty);
    },
  );
  test(
    'edited and cancelled debt events replace effective cash once',
    () async {
      final a = await wallet(usd);
      final id = await debts.create(
        WalletOperation.generate(),
        DebtDraft(
          direction: DebtDirection.lent,
          person: 'Ali',
          principal: Money.parse('100', usd),
          dueOn: '2026-11-01',
        ),
      );
      var d = (await debts.load()).single;
      final eid = await debts.record(
        WalletOperation.generate(),
        id,
        d.debt.revision,
        DebtCashDraft(
          kind: DebtEventKind.payment,
          walletId: a,
          amount: Money.parse('10', usd),
          date: '2026-10-20',
        ),
        await revisions(),
      );
      d = (await debts.load()).single;
      await debts.editCash(
        WalletOperation.generate(),
        eid,
        d.events.single.revision,
        d.debt.revision,
        DebtCashDraft(
          kind: DebtEventKind.payment,
          walletId: a,
          amount: Money.parse('20', usd),
          date: '2026-10-20',
        ),
        await revisions(),
      );
      expect((await report()).debtNet.decimal, '70.00');
      d = (await debts.load()).single;
      await debts.cancelCash(
        WalletOperation.generate(),
        eid,
        d.events.single.revision,
        d.debt.revision,
        await revisions(),
      );
      expect((await report()).debtNet.decimal, '0.00');
    },
  );
  test('first supported date has empty comparison without range failure', () {
    final r = ReportResult.calculate(
      filter: ReportFilter(from: '1900-01-01', to: '1900-01-31'),
      book: book(),
      wallets: [],
      transactions: [],
      transfers: [],
      debts: [],
    );
    expect(r.previous.cashFlow.minorUnits, BigInt.zero);
    expect(r.filter.previous.to, '1899-12-31');
  });
  test(
    'unknown wallet privacy fails closed while repository streams catch up',
    () async {
      final a = await wallet(ils);
      await transaction(a, ils, '1');
      final r = ReportResult.calculate(
        filter: ReportFilter(from: '2026-10-01', to: '2026-10-31'),
        book: book(),
        wallets: [],
        transactions: await transactions.load(),
        transfers: [],
        debts: [],
      );
      expect(r.concealed, true);
    },
  );
  test(
    'rate save snapshots mutable caller list before asynchronous transaction',
    () async {
      final rates = [rate()];
      final saving = exchange.save(WalletOperation.generate(), 0, ils, rates);
      rates.clear();
      await saving;
      expect((await exchange.load()).rates.single.decimal, '3.5');
    },
  );
  test('export privacy rechecks both periods without blocking unrelated hidden wallets', () async {
    final previousWallet = await wallet(ils);
    final unrelated = await wallet(usd);
    await transaction(previousWallet, ils, '5', date: '2026-09-20');
    final snapshot = await report();
    expect(snapshot.concealed, false);
    var all = await wallets.load();
    final other = all.singleWhere((w) => w.wallet.id == unrelated);
    await wallets.setHidden(
      WalletOperation.generate(),
      unrelated,
      other.wallet.revision,
      true,
    );
    expect(snapshot.concealedBy(await wallets.load()), false);
    all = await wallets.load();
    final prior = all.singleWhere((w) => w.wallet.id == previousWallet);
    await wallets.setHidden(
      WalletOperation.generate(),
      previousWallet,
      prior.wallet.revision,
      true,
    );
    expect(snapshot.concealedBy(await wallets.load()), true);
    expect(snapshot.concealedBy([]), true);
  });
  test(
    'currency precision is explicit; absent exact scale has no implicit quote',
    () {
      final c = Currency('USD', 6);
      expect(book().convert(Money.parse('1', c)), null);
      final exact = ExchangeBook(
        currency: ils,
        rates: [
          ManualRate(
            from: c,
            to: ils,
            decimal: '3.5',
            source: 'Manual',
            asOf: '2026-10-20',
            updatedAt: DateTime.utc(2026),
          ),
        ],
      );
      expect(exact.convert(Money.parse('0.001429', c))!.amount.decimal, '0.01');
    },
  );
}

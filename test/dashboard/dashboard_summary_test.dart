import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/dashboard/domain/dashboard_summary.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transfers/domain/wallet_transfer.dart';
import 'package:kim/features/transfers/domain/exchange_rate.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';

void main() {
  final ils = Currency('ILS', 2), usd = Currency('USD', 2);
  late Directory dir;
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository transactions;
  late LocalTransferRepository transfers;
  Future<void> open() async {
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
    wallets = LocalWalletRepository(db);
    transactions = LocalTransactionRepository(db);
    transfers = LocalTransferRepository(db);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim-dashboard-');
    await open();
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<String> wallet({Currency? currency, String opening = '100'}) =>
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
  Future<String> transaction(
    String id,
    String amount, {
    String date = '2026-10-15',
    TransactionKind kind = TransactionKind.expense,
    String? category,
    Currency? currency,
  }) async => transactions.create(
    WalletOperation.generate(),
    TransactionDraft(
      walletId: id,
      kind: kind,
      amount: Money.parse(amount, currency ?? ils),
      category:
          category ?? (kind == TransactionKind.income ? 'salary' : 'food'),
      date: date,
    ),
    await revisions(),
  );
  Future<DashboardSummary> summary({
    Currency? currency,
    DashboardPeriod? period,
  }) async => DashboardSummary(
    wallets: await wallets.load(),
    transactions: await transactions.load(),
    currency: currency ?? ils,
    period: period ?? DashboardPeriod.preset('month', DateTime(2026, 10, 15)),
  );

  test('exact totals derive from stored records, including negatives and huge values after reopen', () async {
    final a = await wallet(opening: '900719925474099312345.67');
    await wallet(opening: '-2.10');
    await transaction(a, '0.11', kind: TransactionKind.income);
    await transaction(a, '0.03');
    await db.close();
    await open();
    final d = await summary();
    expect(d.balance.decimal, '900719925474099312343.65');
    expect(d.income.decimal, '0.11');
    expect(d.expense.decimal, '0.03');
    expect(d.net.decimal, '0.08');
    expect(d.categories['food']!.decimal, '0.03');
    expect(d.activeCount, 2);
  });
  test('date boundaries, edits and cancellation count current business records once', () async {
    final a = await wallet();
    await transaction(a, '1.00', date: '2026-09-30');
    await transaction(a, '2.00', date: '2026-10-01');
    final id = await transaction(a, '3.00', date: '2026-10-31');
    await transaction(a, '4.00', date: '2026-11-01');
    expect((await summary()).expense.decimal, '5.00');
    var t = (await transactions.load()).singleWhere((t) => t.id == id);
    await transactions.edit(
      WalletOperation.generate(),
      id,
      t.revision,
      TransactionDraft(
        walletId: a,
        kind: TransactionKind.expense,
        amount: Money.parse('0.25', ils),
        category: 'bills',
        date: '2026-10-31',
      ),
      await revisions(),
    );
    expect((await summary()).expense.decimal, '2.25');
    t = (await transactions.load()).singleWhere((t) => t.id == id);
    await transactions.delete(
      WalletOperation.generate(),
      id,
      t.revision,
      await revisions(),
    );
    expect((await summary()).expense.decimal, '2.00');
    expect((await summary()).categories.containsKey('bills'), false);
  });
  test(
    'internal transfers do not inflate flow, only live fees are expenses',
    () async {
      final a = await wallet(), b = await wallet(opening: '0');
      final at = DateTime(2026, 10, 15);
      final generated = WalletOperation.generate();
      final id = await transfers.create(
        WalletOperation(generated.id, at),
        TransferDraft(
          sourceId: a,
          destinationId: b,
          amount: Money.parse('20', ils),
          fee: Money.parse('0.35', ils),
          rate: ExchangeRate.parse('1'),
        ),
        await revisions(),
      );
      var d = await summary();
      expect(d.balance.decimal, '99.65');
      expect(d.income.decimal, '0.00');
      expect(d.expense.decimal, '0.35');
      expect(d.categories['transferFee']!.decimal, '0.35');
      final t = (await transfers.load()).single;
      await transfers.cancel(
        WalletOperation.generate(),
        id,
        t.revision,
        await revisions(),
      );
      d = await summary();
      expect(d.balance.decimal, '100.00');
      expect(d.expense.decimal, '0.00');
    },
  );
  test(
    'currency and precision are isolated, including an archived foreign flow',
    () async {
      final a = await wallet(), b = await wallet(currency: usd, opening: '10');
      final c = Currency('ILS', 3);
      await wallet(currency: c, opening: '1.123');
      await transaction(a, '1');
      await transaction(b, '2', currency: usd);
      var d = await summary();
      expect(d.balance.decimal, '99.00');
      expect(d.expense.decimal, '1.00');
      expect(d.excludedCurrencies, containsAll([usd, c]));
      final w = (await wallets.load())
          .singleWhere((w) => w.wallet.id == b)
          .wallet;
      await wallets.setArchived(
        WalletOperation.generate(),
        b,
        w.revision,
        true,
      );
      d = await summary(currency: usd);
      expect(d.balance.decimal, '0.00');
      expect(d.expense.decimal, '2.00');
      expect(d.activeCount, 2);
    },
  );
  test(
    'hidden relevant wallets conceal totals and chart inputs in presentation',
    () async {
      final a = await wallet();
      await transaction(a, '5');
      var w = (await wallets.load()).single.wallet;
      await wallets.setHidden(WalletOperation.generate(), a, w.revision, true);
      expect((await summary()).concealed, true);
      w = (await wallets.load()).single.wallet;
      await wallets.setArchived(
        WalletOperation.generate(),
        a,
        w.revision,
        true,
      );
      expect((await summary()).concealed, true);
      expect(
        (await summary(
          period: DashboardPeriod.preset('lastMonth', DateTime(2026, 10)),
        )).concealed,
        false,
      );
    },
  );
  test(
    'buckets partition all days without gaps and reconcile exactly to totals',
    () async {
      final a = await wallet(opening: '1000');
      for (var day = 1; day <= 31; day++) {
        await transaction(
          a,
          '0.01',
          date: calendarDate(DateTime(2026, 10, day)),
        );
      }
      final d = await summary();
      expect(d.buckets.length, lessThanOrEqualTo(12));
      expect(d.buckets.first.from, '2026-10-01');
      expect(d.buckets.last.to, '2026-10-31');
      expect(
        d.buckets.fold(BigInt.zero, (v, b) => v + b.expense.minorUnits),
        d.expense.minorUnits,
      );
      expect(d.expense.decimal, '0.31');
    },
  );
  test('calendar presets handle year boundary and leap days; ratio remains finite for enormous money', () {
    final week = DashboardPeriod.preset('week', DateTime(2026, 1, 3));
    expect(week.from, '2025-12-28');
    expect(week.to, '2026-01-03');
    final feb = DashboardPeriod.preset('lastMonth', DateTime(2024, 3, 10));
    expect(feb.to, '2024-02-29');
    expect(feb.contains('2024-03-01'), false);
    final huge = BigInt.from(10).pow(1000);
    expect(chartFraction(huge, huge * BigInt.two), .5);
    expect(chartFraction(BigInt.zero, BigInt.zero), 0);
    expect(
      () => DashboardPeriod(DateTime(2026), DateTime(2025)),
      throwsArgumentError,
    );
  });
}

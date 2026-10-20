import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/dashboard/domain/dashboard_summary.dart';
import 'package:kim/features/reports/domain/exchange_book.dart';
import 'package:kim/features/reports/domain/financial_report.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';

void main() {
  test(
    'a multi-year history loads and aggregates within interactive budgets',
    () async {
      final db = await AppDatabase.open(newDatabaseFactoryMemory(), 'scale');
      addTearDown(db.close);
      final ils = Currency('ILS', 2);
      final wallets = LocalWalletRepository(db);
      final tx = LocalTransactionRepository(db);
      final ids = [
        for (var i = 0; i < 4; i++)
          await wallets.create(
            WalletOperation.generate(),
            WalletDraft(
              name: 'W$i',
              color: 'blue',
              icon: 'cash',
              type: 'cash',
              currency: ils,
            ),
            Money.parse('100000', ils),
          ),
      ];
      const count = 1500;
      final revisions = {for (final id in ids) id: 0};
      final write = Stopwatch()..start();
      var expected = BigInt.zero;
      for (var i = 0; i < count; i++) {
        final income = i % 5 == 0;
        final amount = Money(BigInt.from(1000 + i), ils);
        expected += income ? amount.minorUnits : -amount.minorUnits;
        final day = DateTime(2024, 1, 1).add(Duration(days: i % 900));
        final walletId = ids[i % ids.length];
        await tx.create(
          WalletOperation.generate(),
          TransactionDraft(
            walletId: walletId,
            kind: income ? TransactionKind.income : TransactionKind.expense,
            amount: amount,
            category: income ? 'salary' : 'food',
            date: calendarDate(day),
          ),
          Map.of(revisions),
        );
        revisions[walletId] = revisions[walletId]! + 1;
      }
      write.stop();

      final read = Stopwatch()..start();
      final snapshots = await wallets.load();
      final rows = await tx.load();
      read.stop();
      final aggregate = Stopwatch()..start();
      final report = ReportResult.calculate(
        filter: ReportFilter(from: '2024-01-01', to: '2026-12-31'),
        book: ExchangeBook(currency: ils, rates: const []),
        wallets: snapshots,
        transactions: rows,
        transfers: const [],
        debts: const [],
      );
      final dashboard = DashboardSummary(
        wallets: snapshots,
        transactions: rows,
        currency: ils,
        period: DashboardPeriod(DateTime(2024), DateTime(2026, 12, 31)),
      );
      aggregate.stop();

      expect(rows, hasLength(count));
      expect(report.operatingNet.minorUnits, expected);
      expect(dashboard.net.minorUnits, expected);
      expect(
        dashboard.balance.minorUnits,
        BigInt.from(4 * 10000000) + expected,
      );
      // ignore: avoid_print
      print(
        'scale: write ${write.elapsedMilliseconds}ms, '
        'read ${read.elapsedMilliseconds}ms, '
        'aggregate ${aggregate.elapsedMilliseconds}ms',
      );
      // Generous bounds: the VM loads 1500 records in tens of milliseconds.
      expect(read.elapsedMilliseconds, lessThan(1500));
      expect(aggregate.elapsedMilliseconds, lessThan(1000));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

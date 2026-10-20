import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/categories/data/local_category_repository.dart';
import 'package:kim/features/categories/presentation/category_providers.dart';
import 'package:kim/features/debts/data/local_debt_repository.dart';
import 'package:kim/features/debts/presentation/debt_providers.dart';
import 'package:kim/features/reports/data/local_exchange_repository.dart';
import 'package:kim/features/reports/presentation/currency_providers.dart';
import 'package:kim/features/reports/presentation/reports_page.dart';
import 'package:kim/features/reports/presentation/report_charts.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transactions/presentation/transaction_providers.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/presentation/transfer_providers.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/presentation/wallet_providers.dart';

void main() {
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository transactions;
  late LocalExchangeRepository exchange;
  late String cash, pocket, travel;
  final ils = Currency('ILS', 2), usd = Currency('USD', 2);
  Future<void> mount(
    WidgetTester t, {
    bool ar = false,
    bool hiddenPreviousOnly = false,
  }) async {
    t.view.physicalSize = ar ? const Size(390, 844) : const Size(1440, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    db = (await t.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'reports-ui'),
    ))!;
    addTearDown(db.close);
    wallets = LocalWalletRepository(db);
    transactions = LocalTransactionRepository(db);
    exchange = LocalExchangeRepository(db);
    await t.runAsync(() async {
      Future<String> wallet(String name, Currency c) => wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: name,
          color: 'blue',
          icon: 'wallet',
          type: 'cash',
          currency: c,
        ),
        Money.parse('1000', c),
      );
      cash = await wallet('Cash', ils);
      pocket = await wallet('Pocket', ils);
      travel = await wallet('Travel', usd);
      Future<void> tx(
        String id,
        TransactionKind kind,
        String value,
        String category,
        String date,
      ) async {
        final w = (await wallets.load()).firstWhere((w) => w.wallet.id == id);
        await transactions.create(
          WalletOperation.generate(),
          TransactionDraft(
            walletId: id,
            kind: kind,
            amount: Money.parse(value, w.wallet.currency),
            category: category,
            date: date,
          ),
          {id: w.wallet.revision},
        );
      }

      final now = DateTime.now(),
          today = calendarDate(DateTime.now()),
          old = calendarDate(
            DateTime(DateTime.now().year, DateTime.now().month - 1, 5),
          );
      await tx(cash, TransactionKind.income, '100', 'salary', today);
      await tx(cash, TransactionKind.expense, '20', 'food', today);
      await tx(pocket, TransactionKind.income, '40', 'salary', today);
      await tx(pocket, TransactionKind.expense, '5', 'bills', today);
      await tx(travel, TransactionKind.income, '10', 'salary', today);
      await tx(travel, TransactionKind.expense, '3', 'bills', today);
      await tx(cash, TransactionKind.income, '50', 'salary', old);
      await tx(cash, TransactionKind.expense, '7', 'food', old);
      if (hiddenPreviousOnly) {
        final legacy = await wallet('Private old wallet', ils);
        // Seed only within the previous equal-length comparison, irrespective of month length.
        final previous = calendarDate(
          DateTime(now.year, now.month, 1).subtract(const Duration(days: 1)),
        );
        await tx(legacy, TransactionKind.income, '876.54', 'salary', previous);
        final w = (await wallets.load()).firstWhere(
          (w) => w.wallet.id == legacy,
        );
        await wallets.setHidden(
          WalletOperation.generate(),
          legacy,
          w.wallet.revision,
          true,
        );
      }
    });
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(wallets),
          transactionRepositoryProvider.overrideWithValue(transactions),
          exchangeRepositoryProvider.overrideWithValue(exchange),
          categoryRepositoryProvider.overrideWithValue(
            LocalCategoryRepository(db),
          ),
          debtRepositoryProvider.overrideWithValue(LocalDebtRepository(db)),
          transferRepositoryProvider.overrideWithValue(
            LocalTransferRepository(db),
          ),
        ],
        child: MaterialApp(
          locale: Locale(ar ? 'ar' : 'en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ar ? ThemeData.dark() : ThemeData.light(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: EdgeInsets.all(20), child: ReportsPage()),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> select(WidgetTester t, String prefix, String item) async {
    final f = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          w.key.toString().contains(prefix),
    );
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
    await t.tap(find.text(item).last);
    await t.pumpAndSettle();
  }

  testWidgets(
    'real report filters by wallet, category and period without mixing currencies',
    (t) async {
      await mount(t);
      expect(find.textContaining('Incomplete valuation'), findsOneWidget);
      expect(t.widget<DataTable>(find.byType(DataTable)).rows.length, 6);
      await select(t, 'report-wallet-', 'Cash');
      expect(find.textContaining('Incomplete valuation'), findsNothing);
      expect(t.widget<DataTable>(find.byType(DataTable)).rows.length, 2);
      await select(t, 'report-category-', 'Food');
      expect(t.widget<DataTable>(find.byType(DataTable)).rows.length, 1);
      expect(find.text('-20.00 ILS'), findsWidgets);
      await select(t, 'report-period-', 'Last month');
      expect(t.widget<DataTable>(find.byType(DataTable)).rows.length, 1);
      expect(find.text('-7.00 ILS'), findsWidgets);
      expect(find.text('-20.00 ILS'), findsNothing);
    },
  );
  testWidgets(
    'hidden previous-only wallet conceals totals and disables every export',
    (t) async {
      await mount(t, hiddenPreviousOnly: true);
      expect(
        find.textContaining('This report contains a hidden wallet.'),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsNothing);
      expect(find.textContaining('876.54'), findsNothing);
      for (final key in ['csv', 'excel', 'pdf']) {
        expect(
          t
              .widget<OutlinedButton>(find.byKey(ValueKey('export-$key')))
              .onPressed,
          isNull,
        );
      }
      await select(t, 'report-wallet-', 'Cash');
      expect(find.byType(DataTable), findsOneWidget);
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const ValueKey('export-csv')))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets('trend columns expose exact amounts on tap', (t) async {
    await mount(t);
    await select(t, 'report-wallet-', 'Cash');
    final trend = t.widget<ReportTrend>(find.byType(ReportTrend));
    final index = trend.points.indexWhere(
      (p) => p.income.minorUnits > BigInt.zero,
    );
    final bar = find.byKey(ValueKey('report-bar-$index'));
    await t.ensureVisible(bar);
    await t.tap(bar);
    await t.pumpAndSettle();
    expect(find.textContaining('Income: 100.00 ILS'), findsWidgets);
    expect(find.textContaining('Expenses: 20.00 ILS'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('Arabic dark reports fit a narrow screen with real activity', (
    t,
  ) async {
    await mount(t, ar: true);
    expect(
      Directionality.of(t.element(find.text('قصتك المالية بوضوح'))),
      TextDirection.rtl,
    );
    await t.ensureVisible(find.byType(DataTable));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}

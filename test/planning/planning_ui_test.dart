import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/app/kim_app.dart';
import 'package:kim/app/router.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/categories/data/local_category_repository.dart';
import 'package:kim/features/categories/presentation/category_providers.dart';
import 'package:kim/features/budgets/data/local_budget_repository.dart';
import 'package:kim/features/budgets/domain/budget.dart';
import 'package:kim/features/budgets/presentation/budget_providers.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:kim/features/settings/domain/app_settings.dart';
import 'package:kim/features/settings/presentation/settings_controller.dart';
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
  late LocalBudgetRepository budgets;
  late ProviderContainer container;
  late String walletId;
  final ils = Currency('ILS', 2);
  Future<void> seedExpense(String amount) async => transactions.create(
    WalletOperation.generate(),
    TransactionDraft(
      walletId: walletId,
      kind: TransactionKind.expense,
      amount: Money.parse(amount, ils),
      category: 'food',
      date: calendarDate(DateTime.now()),
    ),
    {for (final w in await wallets.load()) w.wallet.id: w.wallet.revision},
  );
  Future<String> seedBudget() => budgets.create(
    WalletOperation.generate(),
    BudgetDraft(
      name: 'Monthly plan',
      limit: Money.parse('100', ils),
      cycle: BudgetCycle.monthly,
      startsOn: BudgetPeriod.containing(
        BudgetCycle.monthly,
        DateTime.now(),
      ).from,
    ),
  );

  Future<void> mount(
    WidgetTester tester, {
    bool ar = false,
    bool withUsage = false,
  }) async {
    tester.view.physicalSize = ar
        ? const Size(390, 844)
        : const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = (await tester.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'planning-ui.db'),
    ))!;
    addTearDown(db.close);
    wallets = LocalWalletRepository(db);
    transactions = LocalTransactionRepository(db);
    budgets = LocalBudgetRepository(db);
    walletId = (await tester.runAsync(
      () => wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Cash',
          color: 'emerald',
          icon: 'wallet',
          type: 'cash',
          currency: ils,
        ),
        Money.parse('1000', ils),
      ),
    ))!;
    if (withUsage) {
      await tester.runAsync(() async {
        await seedExpense('80');
        await seedBudget();
      });
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            LocalCategoryRepository(db),
          ),
          budgetRepositoryProvider.overrideWithValue(budgets),
          walletRepositoryProvider.overrideWithValue(wallets),
          transactionRepositoryProvider.overrideWithValue(transactions),
          transferRepositoryProvider.overrideWithValue(
            LocalTransferRepository(db),
          ),
          settingsRepositoryProvider.overrideWithValue(
            LocalSettingsRepository(db),
          ),
          initialSettingsProvider.overrideWithValue(
            AppSettings(
              languageCode: ar ? 'ar' : 'en',
              theme: ar ? AppTheme.dark : AppTheme.light,
            ),
          ),
        ],
        child: const KimApp(),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(KimApp)));
  }

  Future<void> go(WidgetTester tester, String route) async {
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'custom category flows through editor history chart and real category budget',
    (tester) async {
      await mount(tester);
      await go(tester, '/categories');
      await press(tester, 'category-add');
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        'Coffee test',
      );
      await tester.tap(find.text('Purple'));
      await tester.tap(find.byTooltip('Coffee'));
      await press(tester, 'category-save');
      expect(find.text('Coffee test'), findsOneWidget);
      await go(tester, '/transactions');
      await press(tester, 'transaction-add');
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee test').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('transaction-amount')),
        '25',
      );
      await press(tester, 'transaction-save');
      expect(find.text('Expense · Coffee test'), findsOneWidget);
      await go(tester, '/budgets');
      await press(tester, 'budget-add');
      await tester.enterText(
        find.byKey(const ValueKey('budget-name')),
        'Coffee budget',
      );
      await tester.enterText(find.byKey(const ValueKey('budget-limit')), '100');
      await tester.ensureVisible(find.text('All expenses').last);
      await tester.tap(find.text('All expenses').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee test').last);
      await tester.pumpAndSettle();
      await press(tester, 'budget-save');
      expect(find.text('25.00 ILS'), findsOneWidget);
      expect(find.text('75.00 ILS'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
      await go(tester, '/');
      expect(find.text('Coffee test'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'old expense edit and cancellation update budget alert and dashboard immediately',
    (tester) async {
      await mount(tester, withUsage: true);

      await go(tester, '/budgets');
      expect(find.text('80.0%'), findsOneWidget);
      expect(find.text('Budget alert · 80%'), findsOneWidget);
      await go(tester, '/transactions');
      await press(tester, 'transaction-edit');
      await tester.enterText(
        find.byKey(const ValueKey('transaction-amount')),
        '20',
      );
      await press(tester, 'transaction-save');
      await go(tester, '/budgets');
      expect(find.text('20.0%'), findsOneWidget);
      expect(find.text('Budget alert · 80%'), findsNothing);
      await go(tester, '/transactions');
      await press(tester, 'transaction-delete');
      await press(tester, 'transaction-delete-confirm');
      await go(tester, '/budgets');
      expect(find.text('0.0%'), findsOneWidget);
      expect(find.text('100.00 ILS'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'hidden wallet removes financial progress and alert, including retained reload',
    (tester) async {
      await mount(tester, withUsage: true);

      await go(tester, '/budgets');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.runAsync(() async {
        final w = (await wallets.load()).single.wallet;
        await wallets.setHidden(
          WalletOperation.generate(),
          w.id,
          w.revision,
          true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('80.00 ILS'), findsNothing);
      expect(
        find.text('Amounts and alerts hidden for wallet privacy'),
        findsOneWidget,
      );
      container.invalidate(walletsProvider);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Arabic dark mobile category editor and budget controls fit and save exact amounts',
    (tester) async {
      await mount(tester, ar: true);
      await go(tester, '/categories');
      await press(tester, 'category-add');
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        'الدراسة',
      );
      await press(tester, 'category-save');
      await go(tester, '/budgets');
      await press(tester, 'budget-add');
      await tester.enterText(
        find.byKey(const ValueKey('budget-name')),
        'خطتي الشهرية',
      );
      await tester.enterText(
        find.byKey(const ValueKey('budget-limit')),
        '١٠٠٫٢٥',
      );
      await press(tester, 'budget-save');
      expect(find.text('100.25 ILS'), findsNWidgets(2));
      expect(find.text('0.0%'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(const ValueKey('budgets-page'))),
        ),
        TextDirection.rtl,
      );
      await tester.ensureVisible(find.byType(LinearProgressIndicator));
      expect(tester.takeException(), isNull);
    },
  );
}

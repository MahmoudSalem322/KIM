import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;
import 'package:kim/app/kim_app.dart';
import 'package:kim/app/router.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/categories/data/local_category_repository.dart';
import 'package:kim/features/categories/presentation/category_providers.dart';
import 'package:kim/features/budgets/data/local_budget_repository.dart';
import 'package:kim/features/budgets/presentation/budget_providers.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:kim/features/settings/domain/app_settings.dart';
import 'package:kim/features/settings/presentation/settings_controller.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/presentation/transaction_providers.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/presentation/transfer_providers.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/presentation/wallet_providers.dart';
import 'package:kim/features/debts/data/local_debt_repository.dart';
import 'package:kim/features/debts/presentation/debt_providers.dart';

void main() {
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalDebtRepository debts;
  late ProviderContainer container;
  late String wid;
  final ils = Currency('ILS', 2);
  Future<void> mount(WidgetTester t, {bool ar = false}) async {
    t.view.physicalSize = ar ? const Size(390, 844) : const Size(1440, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    db = (await t.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'debts-ui.db'),
    ))!;
    addTearDown(db.close);
    wallets = LocalWalletRepository(db);
    debts = LocalDebtRepository(db);
    wid = (await t.runAsync(
      () => wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Cash',
          color: 'blue',
          icon: 'wallet',
          type: 'cash',
          currency: ils,
        ),
        Money.parse('1000', ils),
      ),
    ))!;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          debtRepositoryProvider.overrideWithValue(debts),
          categoryRepositoryProvider.overrideWithValue(
            LocalCategoryRepository(db),
          ),
          budgetRepositoryProvider.overrideWithValue(LocalBudgetRepository(db)),
          walletRepositoryProvider.overrideWithValue(wallets),
          transactionRepositoryProvider.overrideWithValue(
            LocalTransactionRepository(db),
          ),
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
    await t.pumpAndSettle();
    container = ProviderScope.containerOf(t.element(find.byType(KimApp)));
  }

  Finder key(String k) => find.byKey(ValueKey(k));
  Future<void> press(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
  }

  Future<void> fill(WidgetTester t, String k, String value) async {
    await t.ensureVisible(key(k));
    await t.enterText(key(k), value);
  }

  Future<void> create(WidgetTester t, {bool ar = false}) async {
    container.read(routerProvider).go('/debts');
    await t.pumpAndSettle();
    await press(t, key('debt-add'));
    await fill(t, 'debt-person', ar ? 'أحمد' : 'Ahmad');
    await fill(t, 'debt-amount', ar ? '٥٠٠٫٢٥' : '500');
    await fill(t, 'debt-date', '2026-01-01');
    await press(t, key('debt-save'));
  }

  testWidgets(
    'administrative record does not move money; repayments edit cancel and recompute overdue status',
    (t) async {
      await mount(t);
      await press(t, find.text('Debts & loans'));
      expect(key('debts-page'), findsOneWidget);
      await create(t);
      expect(
        (await t.runAsync(wallets.load))!.single.balance,
        Money.parse('1000', ils),
      );
      expect(find.text('Overdue'), findsWidgets);
      await press(t, find.text('Record payment'));
      await fill(t, 'debt-amount', '200');
      await press(t, key('debt-save'));
      expect(find.text('300.00 ILS'), findsOneWidget);
      await press(t, find.text('Cash movements & payments'));
      await press(t, find.text('Edit cash movement'));
      await fill(t, 'debt-amount', '500');
      await press(t, key('debt-save'));
      expect(find.text('Settled'), findsWidgets);
      expect(
        (await t.runAsync(wallets.load))!.single.balance,
        Money.parse('1500', ils),
      );
      await press(t, find.text('Cancel cash movement'));
      await press(t, find.widgetWithText(FilledButton, 'Cancel cash movement'));
      expect(find.text('500.00 ILS'), findsNWidgets(3));
      expect(
        (await t.runAsync(wallets.load))!.single.balance,
        Money.parse('1000', ils),
      );
      final data = (await t.runAsync(debts.load))!.single;
      expect(data.events.single.cancelled, isTrue);
      expect(data.remaining, Money.parse('500', ils));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'explicit lending cash movement reduces selected wallet and appears in wallet ledger',
    (t) async {
      await mount(t);
      await create(t);
      await press(t, find.text('Record original cash movement'));
      expect(find.textContaining('real cash movement'), findsOneWidget);
      await press(t, key('debt-save'));
      expect(
        (await t.runAsync(wallets.load))!.single.balance,
        Money.parse('500', ils),
      );
      container.read(routerProvider).go('/wallets/$wid');
      await t.pumpAndSettle();
      expect(find.text('Debt cash paid'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'overpayment validation keeps the cash form open and privacy hides open amounts',
    (t) async {
      await mount(t);
      await create(t);
      await press(t, find.text('Record payment'));
      await fill(t, 'debt-amount', '501');
      await press(t, key('debt-save'));
      expect(
        find.text('The payment exceeds the outstanding debt.'),
        findsOneWidget,
      );
      await fill(t, 'debt-amount', '100');
      await press(t, key('debt-save'));
      await press(t, find.text('Edit debt'));
      await t.runAsync(() async {
        final w = (await wallets.load()).single.wallet;
        await wallets.setHidden(
          WalletOperation.generate(),
          w.id,
          w.revision,
          true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pumpAndSettle();
      expect(key('debt-amount'), findsNothing);
      expect(find.textContaining('Amounts and status hidden'), findsWidgets);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Arabic RTL dark mobile administrative and cash forms save exact decimals',
    (t) async {
      await mount(t, ar: true);
      await create(t, ar: true);
      expect(
        Directionality.of(t.element(key('debts-page'))),
        TextDirection.rtl,
      );
      await press(t, find.text('تسجيل دفعة'));
      await fill(t, 'debt-amount', '١٠٠٫٢٥');
      await press(t, key('debt-save'));
      expect(find.text('400.00 ILS'), findsOneWidget);
      expect(
        (await t.runAsync(wallets.load))!.single.balance,
        Money.parse('1100.25', ils),
      );
      await t.ensureVisible(find.byType(LinearProgressIndicator));
      expect(t.takeException(), isNull);
    },
  );
}

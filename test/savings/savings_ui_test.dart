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
import 'package:kim/features/savings/data/local_savings_repository.dart';
import 'package:kim/features/savings/domain/savings_goal.dart';
import 'package:kim/features/savings/presentation/savings_providers.dart';

void main() {
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalSavingsRepository goals;
  late ProviderContainer container;
  late String wid;
  final ils = Currency('ILS', 2);
  Future<void> mount(
    WidgetTester tester, {
    bool ar = false,
    bool seed = false,
    bool hidden = false,
  }) async {
    tester.view.physicalSize = ar
        ? const Size(390, 844)
        : const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = (await tester.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'savings-ui.db'),
    ))!;
    addTearDown(db.close);
    wallets = LocalWalletRepository(db);
    goals = LocalSavingsRepository(db);
    await tester.runAsync(() async {
      wid = await wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Cash',
          color: 'emerald',
          icon: 'wallet',
          type: 'cash',
          currency: ils,
        ),
        Money.parse('1000', ils),
      );
      await wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Dollars',
          color: 'blue',
          icon: 'bank',
          type: 'bank',
          currency: Currency('USD', 2),
        ),
        Money.parse('500', Currency('USD', 2)),
      );
      if (seed) {
        final id = await goals.create(
          WalletOperation.generate(),
          GoalDraft(
            name: 'Home deposit',
            target: Money.parse('500', ils),
            dueOn: '2027-01-01',
            color: 'blue',
            icon: 'home',
          ),
        );
        await goals.allocate(
          WalletOperation.generate(),
          id,
          0,
          wid,
          0,
          Money.parse('200', ils),
          'Starting today',
        );
      }
      if (hidden) {
        final w = (await wallets.load())
            .singleWhere((w) => w.wallet.id == wid)
            .wallet;
        await wallets.setHidden(
          WalletOperation.generate(),
          wid,
          w.revision,
          true,
        );
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savingsRepositoryProvider.overrideWithValue(goals),
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
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(KimApp)));
  }

  Future<void> go(WidgetTester t, String route) async {
    container.read(routerProvider).go(route);
    await t.pumpAndSettle();
  }

  Future<void> press(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.tap(finder);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));
  Future<void> fill(WidgetTester t, String k, String value) async {
    await t.ensureVisible(key(k));
    await t.enterText(key(k), value);
  }

  testWidgets(
    'empty state navigation goal creation metadata and allocation flow use real repositories',
    (t) async {
      await mount(t);
      await press(t, find.text('Savings goals'));
      expect(key('savings-page'), findsOneWidget);
      expect(find.text('What are you saving for?'), findsOneWidget);
      await press(t, key('goal-add'));
      await fill(t, 'goal-name', 'My trip');
      await fill(t, 'goal-target', '400');
      await press(t, find.widgetWithText(ChoiceChip, 'Travel'));
      await press(t, find.widgetWithText(ChoiceChip, 'Purple'));
      await press(t, key('goal-save'));
      expect(find.text('My trip'), findsOneWidget);
      expect(find.text('0.0%'), findsOneWidget);
      await press(t, find.text('Allocate funds'));
      expect(find.text('This goal’s allocation: 0.00 ILS'), findsOneWidget);
      expect(find.text('Dollars · ILS'), findsNothing);
      await fill(t, 'allocation-amount', '200.25');
      await press(t, key('allocation-save'));
      expect(find.text('50.0%'), findsOneWidget);
      expect(find.text('799.75 ILS'), findsOneWidget);
      final s = (await t.runAsync(goals.load))!.single;
      expect(s.goal.draft.icon, 'travel');
      expect(s.goal.draft.color, 'purple');
      expect(
        (await t.runAsync(wallets.load))!
            .singleWhere((w) => w.wallet.id == wid)
            .balance,
        Money.parse('1000', ils),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'allocation total replacement target edit closing and contribution history stay consistent',
    (t) async {
      await mount(t, seed: true);
      await go(t, '/goals');
      expect(find.text('40.0%'), findsOneWidget);
      await press(t, find.text('Allocate funds'));
      await fill(t, 'allocation-amount', '150');
      await press(t, key('allocation-save'));
      expect(find.text('30.0%'), findsOneWidget);
      await press(t, find.text('Edit goal'));
      await fill(t, 'goal-target', '150');
      await press(t, key('goal-save'));
      expect(find.text('100.0%'), findsOneWidget);
      expect(find.text('Ready to make it happen'), findsOneWidget);
      await press(t, find.text('Contribution history'));
      expect(find.text('Starting today'), findsOneWidget);
      expect(find.text('-50.00 ILS'), findsOneWidget);
      await press(t, find.text('Done'));
      await press(t, find.text('Close goal'));
      await press(t, find.widgetWithText(FilledButton, 'Close goal'));
      expect(find.text('No closed goals yet'), findsNothing);
      expect(find.text('Home deposit'), findsNothing);
      await press(t, find.widgetWithText(FilterChip, 'Show closed'));
      expect(find.text('Home deposit'), findsOneWidget);
      expect(find.text('At closing (released)'), findsOneWidget);
      expect(find.text('Allocate funds'), findsNothing);
      expect(find.text('100.0%'), findsOneWidget);
      final s = (await t.runAsync(goals.load))!.single;
      expect(s.allocated.minorUnits, BigInt.zero);
      expect(s.events.length, 3);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'over-target allocation and lowering target below reserved do not save',
    (t) async {
      await mount(t, seed: true);
      await go(t, '/goals');
      await press(t, find.text('Allocate funds'));
      await fill(t, 'allocation-amount', '500.01');
      await press(t, key('allocation-save'));
      expect(
        find.text('Allocation exceeds the target. Increase the target first.'),
        findsOneWidget,
      );
      await fill(t, 'allocation-amount', '250');
      await press(t, key('allocation-save'));
      expect(find.text('50.0%'), findsOneWidget);
      await press(t, find.text('Edit goal'));
      await fill(t, 'goal-target', '200');
      await press(t, key('goal-save'));
      expect(
        find.text('Release excess allocations before reducing the target.'),
        findsOneWidget,
      );
      expect(
        (await t.runAsync(goals.load))!.single.goal.draft.target,
        Money.parse('500', ils),
      );
    },
  );
  testWidgets(
    'hidden wallet conceals allocations target progress history and retained reload',
    (t) async {
      await mount(t, seed: true, hidden: true);
      await go(t, '/goals');
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('200.00 ILS'), findsNothing);
      expect(find.text('800.00 ILS'), findsNothing);
      expect(find.text('500.00 ILS'), findsNothing);
      final allocate = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Allocate funds'),
      );
      expect(allocate.onPressed, isNull);
      await press(t, find.text('Contribution history'));
      expect(find.text('200.00 ILS'), findsNothing);
      await press(t, find.text('Done'));
      container.invalidate(walletsProvider);
      await t.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  for (final action in ['Allocate funds', 'Edit goal']) {
    testWidgets(
      'open $action dialog hides stale amounts when wallet is hidden in another tab',
      (t) async {
        await mount(t, seed: true);
        await go(t, '/goals');
        await press(t, find.text(action));
        expect(
          key(action == 'Edit goal' ? 'goal-target' : 'allocation-amount'),
          findsOneWidget,
        );
        await t.runAsync(() async {
          final w = (await wallets.load())
              .singleWhere((w) => w.wallet.id == wid)
              .wallet;
          await wallets.setHidden(
            WalletOperation.generate(),
            wid,
            w.revision,
            true,
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await t.pumpAndSettle();
        expect(
          key(action == 'Edit goal' ? 'goal-target' : 'allocation-amount'),
          findsNothing,
        );
        expect(
          key(action == 'Edit goal' ? 'goal-save' : 'allocation-save'),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Arabic dark narrow layout saves Arabic exact decimals and supports release',
    (t) async {
      await mount(t, ar: true);
      await go(t, '/goals');
      expect(
        Directionality.of(t.element(key('savings-page'))),
        TextDirection.rtl,
      );
      await press(t, key('goal-add'));
      await fill(t, 'goal-name', 'صندوق الأمان');
      await fill(t, 'goal-target', '٥٠٠٫٢٥');
      await press(t, key('goal-save'));
      await press(t, find.text('تخصيص الأموال'));
      await fill(t, 'allocation-amount', '١٢٥٫٢٥');
      await press(t, key('allocation-save'));
      expect(find.text('125.25 ILS'), findsNWidgets(2));
      expect(find.text('874.75 ILS'), findsOneWidget);
      await press(t, find.text('تخصيص الأموال'));
      await fill(t, 'allocation-amount', '٠');
      await press(t, key('allocation-save'));
      expect(find.text('0.0%'), findsOneWidget);
      await t.ensureVisible(find.byType(LinearProgressIndicator));
      expect(t.takeException(), isNull);
    },
  );
}

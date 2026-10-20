import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/app/kim_app.dart';
import 'package:kim/app/router.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/backup/data/backup_repository.dart';
import 'package:kim/features/backup/presentation/backup_panel.dart';
import 'package:kim/features/budgets/data/local_budget_repository.dart';
import 'package:kim/features/budgets/domain/budget.dart';
import 'package:kim/features/budgets/presentation/budget_providers.dart';
import 'package:kim/features/categories/data/local_category_repository.dart';
import 'package:kim/features/categories/presentation/category_providers.dart';
import 'package:kim/features/debts/data/local_debt_repository.dart';
import 'package:kim/features/debts/domain/debt.dart';
import 'package:kim/features/debts/presentation/debt_providers.dart';
import 'package:kim/features/notifications/data/local_notice_repository.dart';
import 'package:kim/features/notifications/presentation/notification_providers.dart';
import 'package:kim/features/recurring/data/local_recurring_repository.dart';
import 'package:kim/features/recurring/domain/recurring_payment.dart';
import 'package:kim/features/recurring/presentation/recurring_providers.dart';
import 'package:kim/features/reports/data/local_exchange_repository.dart';
import 'package:kim/features/reports/presentation/currency_providers.dart';
import 'package:kim/features/savings/data/local_savings_repository.dart';
import 'package:kim/features/savings/domain/savings_goal.dart';
import 'package:kim/features/savings/presentation/savings_providers.dart';
import 'package:kim/features/security/data/security_repository.dart';
import 'package:kim/features/security/presentation/security_controller.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:kim/features/settings/domain/app_settings.dart';
import 'package:kim/features/settings/presentation/settings_controller.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transactions/presentation/transaction_providers.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/domain/exchange_rate.dart';
import 'package:kim/features/transfers/domain/wallet_transfer.dart';
import 'package:kim/features/transfers/presentation/transfer_providers.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/presentation/wallet_providers.dart';
import 'package:kim/features/budgets/presentation/budget_editor.dart';
import 'package:kim/features/categories/presentation/categories_page.dart';
import 'package:kim/features/debts/presentation/debt_editor.dart';
import 'package:kim/features/recurring/presentation/recurring_editor.dart';
import 'package:kim/features/savings/presentation/allocation_editor.dart';
import 'package:kim/features/savings/presentation/goal_editor.dart';
import 'package:kim/features/security/presentation/security_gate.dart';
import 'package:kim/features/settings/presentation/settings_page.dart';
import 'package:kim/features/transactions/presentation/transaction_editor.dart';
import 'package:kim/features/transfers/presentation/transfer_editor.dart';
import 'package:kim/features/wallets/presentation/wallet_adjustment.dart';
import 'package:kim/features/wallets/presentation/wallet_editor.dart';

/// Release gate: every route renders a populated workspace without layout
/// exceptions on phones, tablets and desktops, in both directions and themes.
void main() {
  const routes = [
    '/',
    '/wallets',
    '/transactions',
    '/categories',
    '/transfers',
    '/budgets',
    '/goals',
    '/recurring',
    '/notifications',
    '/debts',
    '/reports',
    '/currencies',
    '/settings',
    '/missing-page',
  ];
  final configs = <({Size size, String lang, AppTheme theme})>[
    (size: const Size(320, 640), lang: 'ar', theme: AppTheme.dark),
    (size: const Size(320, 640), lang: 'en', theme: AppTheme.light),
    (size: const Size(360, 740), lang: 'ar', theme: AppTheme.light),
    (size: const Size(768, 1024), lang: 'ar', theme: AppTheme.dark),
    (size: const Size(768, 1024), lang: 'en', theme: AppTheme.dark),
    (size: const Size(1024, 700), lang: 'en', theme: AppTheme.light),
    (size: const Size(1440, 900), lang: 'ar', theme: AppTheme.light),
  ];

  Future<String> seed(AppDatabase db) async {
    final ils = Currency('ILS', 2), usd = Currency('USD', 2);
    final wallets = LocalWalletRepository(db);
    Future<Map<String, int>> revisions() async => {
      for (final w in await wallets.load()) w.wallet.id: w.wallet.revision,
    };
    final cash = await wallets.create(
      WalletOperation.generate(),
      WalletDraft(
        name: 'محفظة المصروفات اليومية للعائلة والمنزل والسفر',
        color: 'emerald',
        icon: 'cash',
        type: 'cash',
        currency: ils,
      ),
      Money.parse('9007199254740993.25', ils),
    );
    final bank = await wallets.create(
      WalletOperation.generate(),
      WalletDraft(
        name: 'International savings account with a long name',
        color: 'navy',
        icon: 'bank',
        type: 'bank',
        currency: usd,
      ),
      Money.parse('123456789.99', usd),
    );
    final today = calendarDate(DateTime.now());
    final tx = LocalTransactionRepository(db);
    for (final (kind, category, amount) in [
      (TransactionKind.income, 'salary', '45000.50'),
      (TransactionKind.expense, 'food', '1234567.89'),
      (TransactionKind.expense, 'housing', '3500'),
    ]) {
      await tx.create(
        WalletOperation.generate(),
        TransactionDraft(
          walletId: cash,
          kind: kind,
          amount: Money.parse(amount, ils),
          category: category,
          date: today,
          notes: 'ملاحظة طويلة للتحقق من التفاف النص في الشاشات الضيقة',
        ),
        await revisions(),
      );
    }
    await LocalTransferRepository(db).create(
      WalletOperation.generate(),
      TransferDraft(
        sourceId: bank,
        destinationId: cash,
        amount: Money.parse('1000', usd),
        fee: Money.parse('5', usd),
        rate: ExchangeRate.parse('3.712345678901'),
      ),
      await revisions(),
    );
    await LocalBudgetRepository(db).create(
      WalletOperation.generate(),
      BudgetDraft(
        name: 'ميزانية الطعام الشهرية للعائلة',
        limit: Money.parse('1000000', ils),
        cycle: BudgetCycle.monthly,
        startsOn: calendarDate(
          DateTime(DateTime.now().year, DateTime.now().month),
        ),
        category: 'food',
      ),
    );
    final savings = LocalSavingsRepository(db);
    final goal = await savings.create(
      WalletOperation.generate(),
      GoalDraft(
        name: 'Emergency fund for the whole family',
        target: Money.parse('99999999', ils),
        dueOn: '2027-12-31',
        color: 'blue',
        icon: 'travel',
      ),
    );
    await savings.allocate(
      WalletOperation.generate(),
      goal,
      0,
      cash,
      (await revisions())[cash]!,
      Money.parse('5000', ils),
      'first',
    );
    await LocalDebtRepository(db).create(
      WalletOperation.generate(),
      DebtDraft(
        direction: DebtDirection.lent,
        person: 'شخص باسم طويل جدًا لاختبار العرض',
        principal: Money.parse('750000', ils),
        dueOn: '2026-01-01',
      ),
    );
    await LocalRecurringRepository(db).create(
      WalletOperation.generate(),
      RecurringDraft(
        name: 'Streaming subscription with a long name',
        amount: Money.parse('49.90', ils),
        walletId: cash,
        cycle: RecurringCycle.monthly,
        nextDate: today,
        category: 'bills',
      ),
    );
    await SecurityRepository(db).setPin('123456');
    return cash;
  }

  Future<(ProviderContainer, String, AppDatabase)> mount(
    WidgetTester t,
    ({Size size, String lang, AppTheme theme}) config,
  ) async {
    t.view.physicalSize = config.size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final db = (await t.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'matrix'),
    ))!;
    addTearDown(db.close);
    final cash = (await t.runAsync(() => seed(db)))!;
    final container = ProviderContainer(
      overrides: [
        securityRepositoryProvider.overrideWithValue(SecurityRepository(db)),
        backupRepositoryProvider.overrideWithValue(BackupRepository(db)),
        exchangeRepositoryProvider.overrideWithValue(
          LocalExchangeRepository(db),
        ),
        recurringRepositoryProvider.overrideWithValue(
          LocalRecurringRepository(db),
        ),
        noticeRepositoryProvider.overrideWithValue(LocalNoticeRepository(db)),
        debtRepositoryProvider.overrideWithValue(LocalDebtRepository(db)),
        savingsRepositoryProvider.overrideWithValue(LocalSavingsRepository(db)),
        categoryRepositoryProvider.overrideWithValue(
          LocalCategoryRepository(db),
        ),
        budgetRepositoryProvider.overrideWithValue(LocalBudgetRepository(db)),
        settingsRepositoryProvider.overrideWithValue(
          LocalSettingsRepository(db),
        ),
        initialSettingsProvider.overrideWithValue(
          AppSettings(languageCode: config.lang, theme: config.theme),
        ),
        walletRepositoryProvider.overrideWithValue(LocalWalletRepository(db)),
        transactionRepositoryProvider.overrideWithValue(
          LocalTransactionRepository(db),
        ),
        transferRepositoryProvider.overrideWithValue(
          LocalTransferRepository(db),
        ),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KimApp()),
    );
    await drain(t);
    // The PIN gate hides the workspace until unlocked.
    expect(find.byKey(const ValueKey('nav-wallets')), findsNothing);
    await t.runAsync(
      () =>
          container.read(securityControllerProvider.notifier).unlock('123456'),
    );
    await drain(t);
    expect(find.byKey(const ValueKey('lock-workspace')), findsOneWidget);
    return (container, cash, db);
  }

  for (final config in configs) {
    final label =
        '${config.size.width.toInt()}x${config.size.height.toInt()} '
        '${config.lang} ${config.theme.name}';
    testWidgets('all routes render without layout errors at $label', (t) async {
      final (container, cash, _) = await mount(t, config);
      for (final route in [...routes, '/wallets/$cash']) {
        container.read(routerProvider).go(route);
        await drain(t);
        final error = t.takeException();
        expect(error, isNull, reason: '$route at $label: $error');
        expect(find.byType(ErrorWidget), findsNothing, reason: route);
      }
    });
  }

  for (final lang in ['ar', 'en']) {
    testWidgets('every editor dialog fits a 320px phone in $lang', (t) async {
      final (container, _, db) = await mount(t, (
        size: const Size(320, 640),
        lang: lang,
        theme: AppTheme.dark,
      ));
      container.read(routerProvider).go('/settings');
      await drain(t);
      final wallets = (await t.runAsync(LocalWalletRepository(db).load))!;
      final transfer = (await t.runAsync(LocalTransferRepository(db).load))!
          .first;
      final row = (await t.runAsync(LocalTransactionRepository(db).load))!
          .first;
      final debt = (await t.runAsync(LocalDebtRepository(db).load))!.first;
      final goals = (await t.runAsync(LocalSavingsRepository(db).load))!;
      final budget = (await t.runAsync(LocalBudgetRepository(db).load))!.first;
      final plan = (await t.runAsync(LocalRecurringRepository(db).load))!.first;
      BuildContext page() => t.element(find.byType(SettingsPage));
      final editors = <String, void Function()>{
        'wallet': () => showWalletEditor(page()),
        'edit wallet': () => showWalletEditor(page(), wallet: wallets.first),
        'adjust wallet': () => showWalletAdjustment(page(), wallets.first),
        'income': () => showTransactionEditor(
          page(),
          wallets,
          initialKind: TransactionKind.income,
        ),
        'edit transaction': () =>
            showTransactionEditor(page(), wallets, transaction: row),
        'transfer': () => showTransferEditor(page(), wallets),
        'edit transfer': () =>
            showTransferEditor(page(), wallets, transfer: transfer),
        'category': () => showCategoryEditor(page()),
        'budget': () => showBudgetEditor(page(), budget: budget),
        'goal': () => showGoalEditor(page(), goal: goals.first.goal),
        'allocation': () =>
            showAllocationEditor(page(), goals.first, goals, wallets),
        'debt': () => showDebtEditor(page(), debt: debt),
        'debt payment': () => showDebtEditor(
          page(),
          debt: debt,
          kind: DebtEventKind.payment,
          wallets: wallets,
        ),
        'recurring': () => showRecurringEditor(page(), payment: plan),
        'pin': () => showPinEditor(
          page(),
          t.element(find.byType(SettingsPage)) as WidgetRef,
        ),
      };
      for (final entry in editors.entries) {
        entry.value();
        await drain(t);
        expect(find.byType(Dialog), findsWidgets, reason: entry.key);
        final error = t.takeException();
        expect(error, isNull, reason: '${entry.key} in $lang: $error');
        Navigator.of(t.element(find.byType(Dialog).last)).pop();
        await drain(t);
      }
    });
  }
}

Future<void> drain(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
  }
  await t.pump(const Duration(seconds: 1));
}

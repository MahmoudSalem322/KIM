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
import 'package:kim/features/debts/data/local_debt_repository.dart';
import 'package:kim/features/debts/presentation/debt_providers.dart';
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
import 'package:kim/features/recurring/data/local_recurring_repository.dart';
import 'package:kim/features/recurring/domain/recurring_payment.dart';
import 'package:kim/features/recurring/presentation/recurring_providers.dart';
import 'package:kim/features/notifications/data/local_notice_repository.dart';
import 'package:kim/features/notifications/platform/reminder_adapter.dart';
import 'package:kim/features/notifications/presentation/notification_providers.dart';
import 'package:kim/features/notifications/presentation/recurring_runtime.dart';

class FakeReminders implements ReminderAdapter {
  bool granted = false;
  int requests = 0;
  @override
  bool get supported => true;
  @override
  bool get schedulesWhileClosed => false;
  @override
  Future<bool> requestPermission() async {
    requests++;
    return granted;
  }

  @override
  Future<void> show(int id, String body) async {}
  @override
  Future<void> synchronize(List<LocalReminder> reminders, String body) async {}
  @override
  Future<void> disable() async {}
}

void main() {
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalRecurringRepository plans;
  late LocalNoticeRepository notices;
  late ProviderContainer container;
  late FakeReminders adapter;
  late String wid;
  late DateTime clock;
  final ils = Currency('ILS', 2), now = DateTime(2026, 10, 17);
  Future<void> mount(
    WidgetTester t, {
    bool ar = false,
    bool seed = false,
    bool hidden = false,
    bool runtime = false,
  }) async {
    clock = now;
    t.view.physicalSize = ar ? const Size(390, 844) : const Size(1440, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    db = (await t.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'recurring-ui.db'),
    ))!;
    addTearDown(db.close);
    wallets = LocalWalletRepository(db);
    plans = LocalRecurringRepository(db);
    notices = LocalNoticeRepository(db);
    adapter = FakeReminders();
    await t.runAsync(() async {
      wid = await wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Cash',
          color: 'blue',
          icon: 'wallet',
          type: 'cash',
          currency: ils,
        ),
        Money.parse('1000', ils),
      );
      if (seed) {
        await plans.create(
          WalletOperation.generate(),
          RecurringDraft(
            name: 'Internet',
            amount: Money.parse('10', ils),
            walletId: wid,
            cycle: RecurringCycle.daily,
            nextDate: '2026-10-15',
            category: 'bills',
            automatic: true,
          ),
        );
      }
      if (hidden) {
        await wallets.setHidden(WalletOperation.generate(), wid, 0, true);
      }
    });
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          recurringRepositoryProvider.overrideWithValue(plans),
          noticeRepositoryProvider.overrideWithValue(notices),
          reminderAdapterProvider.overrideWithValue(adapter),
          appClockProvider.overrideWithValue(() => clock),
          debtRepositoryProvider.overrideWithValue(LocalDebtRepository(db)),
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
        child: runtime
            ? const RecurringRuntime(child: KimApp())
            : const KimApp(),
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

  Future<void> go(WidgetTester t, String route) async {
    container.read(routerProvider).go(route);
    await t.pumpAndSettle();
  }

  testWidgets(
    'real form saves reminder-only schedule; calendar filtering does not debit and explicit payment does',
    (t) async {
      await mount(t);
      await press(t, find.text('Recurring payments'));
      await press(t, key('recurring-add'));
      await fill(t, 'recurring-name', 'Streaming');
      await fill(t, 'recurring-amount', '25.50');
      await press(t, key('recurring-save'));
      expect(find.text('25.50 ILS'), findsOneWidget);
      expect(
        (await t.runAsync(wallets.load))!.single.balance,
        Money.parse('1000', ils),
      );
      await press(t, key('calendar-2026-10-17'));
      expect(find.text('Streaming'), findsOneWidget);
      await press(t, find.text('Record due payment'));
      await press(t, find.widgetWithText(FilledButton, 'Record due payment'));
      expect(
        (await t.runAsync(wallets.load))!.single.balance,
        Money.parse('974.50', ils),
      );
      await press(t, find.textContaining('All subscriptions').last);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'processing catch-up updates real expenses and calendar once and center read dismiss state persists',
    (t) async {
      await mount(t, seed: true);
      await go(t, '/recurring');
      await press(t, find.text('Process due payments'));
      expect((await t.runAsync(plans.occurrences))!.length, 3);
      expect(
        (await t.runAsync(wallets.load))!.single.balance,
        Money.parse('970', ils),
      );
      await go(t, '/notifications');
      expect(find.text('Subscription expense recorded'), findsNWidgets(3));
      await press(t, find.text('Mark read').first);
      await press(t, find.widgetWithText(FilterChip, 'Unread only'));
      expect(find.text('Subscription expense recorded'), findsNWidgets(2));
      await press(t, find.text('Dismiss alert').first);
      expect(find.text('Subscription expense recorded'), findsOneWidget);
      final state = (await t.runAsync(notices.load))!;
      expect(state.read.length, 1);
      expect(state.dismissed.length, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'pause edit resume cancel preserve history and never replay while paused',
    (t) async {
      await mount(t, seed: true);
      await go(t, '/recurring');
      await press(t, find.text('Pause'));
      await press(t, find.text('Process due payments'));
      expect((await t.runAsync(plans.occurrences))!, isEmpty);
      await press(t, find.text('Edit subscription'));
      await fill(t, 'recurring-name', 'New internet');
      await fill(t, 'recurring-amount', '20');
      await press(t, key('recurring-save'));
      await press(t, find.text('Resume'));
      await press(t, find.widgetWithText(FilledButton, 'Resume'));
      await press(t, find.text('Process due payments'));
      expect(
        (await t.runAsync(wallets.load))!.single.balance,
        Money.parse('940', ils),
      );
      await press(t, find.text('Cancel subscription'));
      await press(t, find.widgetWithText(FilledButton, 'Cancel subscription'));
      expect(
        (await t.runAsync(plans.load))!.single.status,
        RecurringStatus.cancelled,
      );
      expect((await t.runAsync(plans.occurrences))!.length, 3);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'local notifications require explicit permission and denial leaves internal center usable',
    (t) async {
      await mount(t, seed: true);
      await go(t, '/notifications');
      expect(adapter.requests, 0);
      await press(t, find.text('Enable local notifications'));
      expect(
        find.textContaining('Notification permission was not granted'),
        findsOneWidget,
      );
      expect((await t.runAsync(notices.load))!.enabled, isFalse);
      adapter.granted = true;
      await press(t, find.text('Enable local notifications'));
      expect((await t.runAsync(notices.load))!.enabled, isTrue);
      await press(t, find.text('Disable local notifications'));
      expect((await t.runAsync(notices.load))!.enabled, isFalse);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'hidden wallet removes subscription amounts forecasts and internal alerts including reload',
    (t) async {
      await mount(t, seed: true, hidden: true);
      await go(t, '/recurring');
      expect(find.text('10.00 ILS'), findsNothing);
      expect(
        find.text('Payment details hidden for wallet privacy'),
        findsOneWidget,
      );
      await go(t, '/notifications');
      expect(find.text('Internet'), findsNothing);
      container.invalidate(walletsProvider);
      await t.pump();
      expect(find.text('Internet'), findsNothing);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Arabic dark narrow calendar and editor preserve exact decimals and RTL',
    (t) async {
      await mount(t, ar: true);
      await go(t, '/recurring');
      expect(
        Directionality.of(t.element(key('recurring-page'))),
        TextDirection.rtl,
      );
      await press(t, key('recurring-add'));
      await fill(t, 'recurring-name', 'اشتراك الدراسة');
      await fill(t, 'recurring-amount', '٢٥٫٢٥');
      await press(t, key('recurring-save'));
      expect(find.text('25.25 ILS'), findsOneWidget);
      await press(t, key('calendar-2026-10-17'));
      expect(find.text('اشتراك الدراسة'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'production lifecycle catches up on opening and resume, never while paused or on repeated resume',
    (t) async {
      await mount(t, seed: true, runtime: true);
      Future<void> drain() async {
        for (var i = 0; i < 25; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump(const Duration(milliseconds: 20));
        }
      }

      await drain();
      expect(
        container.read(walletsProvider).requireValue.single.balance,
        Money.parse('970', ils),
      );
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      clock = DateTime(2026, 10, 18);
      await t.pump(const Duration(minutes: 1));
      await drain();
      expect(
        container.read(walletsProvider).requireValue.single.balance,
        Money.parse('970', ils),
      );
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await drain();
      expect(
        container.read(walletsProvider).requireValue.single.balance.decimal,
        '960.00',
        reason: '${container.read(processingProvider)}',
      );
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await drain();
      expect(
        container.read(walletsProvider).requireValue.single.balance,
        Money.parse('960', ils),
      );
      expect(adapter.requests, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}

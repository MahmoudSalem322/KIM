import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/dashboard/presentation/dashboard_page.dart';
import 'package:kim/features/dashboard/presentation/dashboard_charts.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/presentation/wallet_providers.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transactions/presentation/transaction_providers.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/presentation/transfer_providers.dart';
import 'package:kim/shared/design_system/app_theme.dart';

void main() {
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository transactions;
  late ProviderContainer container;
  Completer<void>? gate;
  Future<void> mount(
    WidgetTester tester, {
    bool ar = false,
    bool empty = false,
  }) async {
    tester.view.physicalSize = ar
        ? const Size(390, 844)
        : const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = (await tester.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'dashboard.db'),
    ))!;
    wallets = LocalWalletRepository(db);
    transactions = LocalTransactionRepository(db);
    addTearDown(db.close);
    await tester.runAsync(() async {
      if (empty) return;
      for (final c in [Currency('ILS', 2), Currency('USD', 2)]) {
        final id = await wallets.create(
          WalletOperation.generate(),
          WalletDraft(
            name: c.code,
            color: 'emerald',
            icon: 'wallet',
            type: 'cash',
            currency: c,
          ),
          Money.parse('100', c),
        );
        await transactions.create(
          WalletOperation.generate(),
          TransactionDraft(
            walletId: id,
            kind: TransactionKind.expense,
            amount: Money.parse('12.35', c),
            category: 'food',
            date: calendarDate(DateTime.now()),
          ),
          {
            for (final w in await wallets.load())
              w.wallet.id: w.wallet.revision,
          },
        );
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(wallets),
          transactionRepositoryProvider.overrideWithValue(transactions),
          transferRepositoryProvider.overrideWithValue(
            LocalTransferRepository(db),
          ),
          walletsProvider.overrideWith((ref) async* {
            if (gate != null) await gate!.future;
            yield* wallets.watch();
          }),
        ],
        child: MaterialApp(
          theme: AppThemeData.build(
            ar ? Brightness.dark : Brightness.light,
            ar ? 'ar' : 'en',
          ),
          locale: Locale(ar ? 'ar' : 'en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: DashboardPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );
  }

  testWidgets(
    'real data, currency changes, chart selection and period filtering',
    (tester) async {
      await mount(tester);
      expect(find.text('87.65 ILS'), findsWidgets);
      expect(
        find.byKey(const ValueKey('dashboard-incomplete')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('spend-food')));
      await tester.tap(find.byKey(const ValueKey('spend-food')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('spend-food')))
            .selected,
        true,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('flow-bucket-0')));
      await tester.tap(find.byKey(const ValueKey('flow-bucket-0')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('dashboard-currency-ILS-2')),
      );
      await tester.tap(find.byKey(const ValueKey('dashboard-currency-ILS-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD · 2 decimal places').last);
      await tester.pumpAndSettle();
      expect(find.text('87.65 USD'), findsWidgets);
      await tester.ensureVisible(
        find.byKey(const ValueKey('dashboard-period-month')),
      );
      await tester.tap(find.byKey(const ValueKey('dashboard-period-month')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last month').last);
      await tester.pumpAndSettle();
      expect(find.text('No expenses in this period'), findsOneWidget);
      expect(find.text('0.00 USD'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'income shortcut opens the existing editor with income selected and saves actual data',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('dashboard-income')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('transaction-amount')),
        '2.10',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('transaction-save')),
      );
      await tester.tap(find.byKey(const ValueKey('transaction-save')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      final records = (await tester.runAsync(transactions.load))!;
      expect(
        records
            .where((t) => t.draft.kind == TransactionKind.income)
            .single
            .draft
            .amount
            .decimal,
        '2.10',
      );
      expect(find.text('2.10 ILS'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('dashboard-transfer')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('transfer-save')), findsOneWidget);
    },
  );

  testWidgets(
    'hidden wallet removes charts, exact totals and tooltip data even during refresh',
    (tester) async {
      await mount(tester);
      final w = (await tester.runAsync(wallets.load))!.first.wallet;
      await tester.runAsync(
        () => wallets.setHidden(
          WalletOperation.generate(),
          w.id,
          w.revision,
          true,
        ),
      );
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (container
                .read(walletsProvider)
                .value
                ?.any((w) => w.wallet.hidden) ==
            true) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(find.byType(FlowChart), findsNothing);
      expect(find.text('87.65 ILS'), findsNothing);
      expect(find.text('Amounts hidden for wallet privacy'), findsOneWidget);
      gate = Completer<void>();
      container.invalidate(walletsProvider);
      await tester.pump();
      expect(find.byType(FlowChart), findsNothing);
      expect(find.text('87.65 ILS'), findsNothing);
      gate!.complete();
      gate = null;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Arabic mobile dashboard renders RTL without overflow', (
    tester,
  ) async {
    await mount(tester, ar: true);
    expect(
      Directionality.of(tester.element(find.byType(DashboardPage))),
      TextDirection.rtl,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('spend-food')));
    await tester.pumpAndSettle();
    expect(find.text('أين تذهب أموالك؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'empty dashboard disables financial shortcuts and explains first wallet',
    (tester) async {
      await mount(tester, empty: true);
      expect(find.text('Start your financial story'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('dashboard-income')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('dashboard-transfer')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

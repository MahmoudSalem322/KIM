import 'package:kim/features/reports/data/local_exchange_repository.dart';
import 'package:kim/features/reports/presentation/currency_providers.dart';
import 'package:kim/features/categories/data/local_category_repository.dart';
import 'package:kim/features/categories/presentation/category_providers.dart';
import 'package:kim/features/budgets/data/local_budget_repository.dart';
import 'package:kim/features/budgets/presentation/budget_providers.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/presentation/wallet_providers.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transactions/presentation/transaction_providers.dart';
import 'package:kim/features/transactions/presentation/transactions_page.dart';

void main() {
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository repo;
  late String id;
  Completer<void>? refreshGate;
  Future<void> mount(WidgetTester tester, {bool ar = false}) async {
    tester.view.physicalSize = ar
        ? const Size(390, 844)
        : const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = (await tester.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'ui.db'),
    ))!;
    wallets = LocalWalletRepository(db);
    repo = LocalTransactionRepository(db);
    id = (await tester.runAsync(
      () => wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Cash',
          color: 'emerald',
          icon: 'wallet',
          type: 'cash',
          currency: Currency('ILS', 2),
        ),
        Money.parse('100.00', Currency('ILS', 2)),
      ),
    ))!;
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exchangeRepositoryProvider.overrideWithValue(
            LocalExchangeRepository(db),
          ),
          categoryRepositoryProvider.overrideWithValue(
            LocalCategoryRepository(db),
          ),
          budgetRepositoryProvider.overrideWithValue(LocalBudgetRepository(db)),
          walletRepositoryProvider.overrideWithValue(wallets),
          walletsProvider.overrideWith((ref) async* {
            final gate = refreshGate;
            if (gate != null) await gate.future;
            yield* wallets.watch();
          }),
          transactionRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: Locale(ar ? 'ar' : 'en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(
            body: SingleChildScrollView(child: TransactionsPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('transaction-save')));
    await tester.tap(find.byKey(const ValueKey('transaction-save')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'real create edit and cancellation update wallet and retain cancelled evidence',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('transaction-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('transaction-amount')),
        '12.35',
      );
      await tester.enterText(
        find.byKey(const ValueKey('transaction-notes')),
        'Lunch',
      );
      await save(tester);
      expect(find.text('Lunch'), findsOneWidget);
      expect(
        (await tester.runAsync(wallets.load))!.single.balance.decimal,
        '87.65',
      );
      await tester.tap(find.byKey(const ValueKey('transaction-edit')).first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('transaction-amount')),
        '5.10',
      );
      await tester.enterText(
        find.byKey(const ValueKey('transaction-date')),
        '1999-01-01',
      );
      await save(tester);
      expect(
        (await tester.runAsync(wallets.load))!.single.balance.decimal,
        '94.90',
      );
      await tester.tap(find.byKey(const ValueKey('transaction-delete')).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('transaction-delete-confirm')),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(wallets.load))!.single.balance.decimal,
        '100.00',
      );
      expect((await tester.runAsync(repo.load))!.single.deleted, true);
    },
  );
  testWidgets('Arabic compact form rejects invalid money and calendar date', (
    tester,
  ) async {
    await mount(tester, ar: true);
    await tester.tap(find.byKey(const ValueKey('transaction-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('transaction-amount')),
      '٠٫٠٠',
    );
    await tester.enterText(
      find.byKey(const ValueKey('transaction-date')),
      '2023-02-29',
    );
    await save(tester);
    expect(await tester.runAsync(repo.load), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('transaction-amount')),
      '١٫٢٥',
    );
    await tester.enterText(
      find.byKey(const ValueKey('transaction-date')),
      '2000-02-29',
    );
    await save(tester);
    expect(
      (await tester.runAsync(wallets.load))!.single.balance.decimal,
      '98.75',
    );
  });
  testWidgets('search hides nonmatching real transactions and resets', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(
      () => repo.create(
        WalletOperation.generate(),
        TransactionDraft(
          walletId: id,
          kind: TransactionKind.income,
          amount: Money.parse('10.00', Currency('ILS', 2)),
          category: 'salary',
          date: '2020-01-01',
          notes: 'Salary January',
        ),
        {id: 0},
      ),
    );
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 30 && find.text('Salary January').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Salary January'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('transaction-search')),
      'not found',
    );
    await tester.pumpAndSettle();
    expect(find.text('Salary January'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('transaction-search')),
      'january',
    );
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 30 && find.text('Salary January').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Salary January'), findsOneWidget);
  });
  testWidgets('live hide conceals list and clears open edit amount', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(
      () => repo.create(
        WalletOperation.generate(),
        TransactionDraft(
          walletId: id,
          kind: TransactionKind.expense,
          amount: Money.parse('7.25', Currency('ILS', 2)),
          category: 'food',
          date: '2020-01-01',
        ),
        {id: 0},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transaction-edit')).first);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => wallets.setHidden(WalletOperation.generate(), id, 1, true),
    );
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 30 && find.textContaining('7.25').evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
    final field = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const ValueKey('transaction-amount')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(field.controller!.text, '');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('transaction-amount')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      true,
    );
    expect(find.textContaining('7.25'), findsNothing);
  });
  testWidgets(
    'refreshing visible wallet data conceals and clears editor until new snapshot',
    (tester) async {
      await mount(tester);
      await tester.runAsync(
        () => repo.create(
          WalletOperation.generate(),
          TransactionDraft(
            walletId: id,
            kind: TransactionKind.expense,
            amount: Money.parse('7.25', Currency('ILS', 2)),
            category: 'food',
            date: '2020-01-01',
          ),
          {id: 0},
        ),
      );
      for (
        var i = 0;
        i < 30 &&
            find.byKey(const ValueKey('transaction-edit')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('transaction-edit')).first);
      await tester.pumpAndSettle();
      refreshGate = Completer<void>();
      addTearDown(() {
        if (refreshGate != null && !refreshGate!.isCompleted) {
          refreshGate!.complete();
        }
        refreshGate = null;
      });
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransactionsPage)),
      );
      container.invalidate(walletsProvider);
      await tester.pump();
      await tester.pump();
      expect(container.read(walletsProvider).isLoading, true);
      final field = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(const ValueKey('transaction-amount')),
          matching: find.byType(TextFormField),
        ),
      );
      expect(field.controller!.text, isEmpty);
      expect(find.textContaining('7.25'), findsNothing);
      refreshGate!.complete();
      refreshGate = null;
      await tester.pumpAndSettle();
    },
  );
}

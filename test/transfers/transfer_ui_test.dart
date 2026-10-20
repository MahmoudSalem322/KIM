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
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/presentation/wallet_providers.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/presentation/transfer_providers.dart';
import 'package:kim/features/transfers/presentation/transfers_page.dart';
import 'package:kim/features/transfers/presentation/transfer_editor.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/presentation/transaction_row.dart';

void main() {
  late AppDatabase db;
  late LocalWalletRepository wallets;
  late LocalTransferRepository transfers;
  Completer<void>? refreshGate;
  Future<void> mount(WidgetTester tester, {bool ar = false}) async {
    tester.view.physicalSize = ar
        ? const Size(390, 844)
        : const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = (await tester.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'transfers.db'),
    ))!;
    wallets = LocalWalletRepository(db);
    transfers = LocalTransferRepository(db);
    addTearDown(db.close);
    for (final name in ['Cash', 'Savings']) {
      await tester.runAsync(
        () => wallets.create(
          WalletOperation.generate(),
          WalletDraft(
            name: name,
            color: 'emerald',
            icon: 'wallet',
            type: 'cash',
            currency: Currency('ILS', 2),
          ),
          Money.parse(name == 'Cash' ? '100' : '0', Currency('ILS', 2)),
        ),
      );
    }
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
          transferRepositoryProvider.overrideWithValue(transfers),
        ],
        child: MaterialApp(
          locale: Locale(ar ? 'ar' : 'en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(
            body: SingleChildScrollView(child: TransfersPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)).first);
    await tester.tap(find.byKey(ValueKey(key)).first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create edit cancel retains history and only fees enter expenses',
    (tester) async {
      await mount(tester);
      await press(tester, 'transfer-add');
      await tester.enterText(
        find.byKey(const ValueKey('transfer-amount')),
        '10.25',
      );
      await tester.enterText(
        find.byKey(const ValueKey('transfer-fee')),
        '0.35',
      );
      await tester.enterText(
        find.byKey(const ValueKey('transfer-notes')),
        'Reserve',
      );
      await press(tester, 'transfer-save');
      expect(find.text('Reserve'), findsOneWidget);
      expect(
        (await tester.runAsync(wallets.load))!.first.balance.decimal,
        '89.40',
      );
      await press(tester, 'transfer-edit');
      await tester.enterText(
        find.byKey(const ValueKey('transfer-amount')),
        '5.10',
      );
      await press(tester, 'transfer-save');
      expect(
        (await tester.runAsync(wallets.load))!.first.balance.decimal,
        '94.55',
      );
      await press(tester, 'transfer-cancel');
      await press(tester, 'transfer-cancel-confirm');
      expect(
        (await tester.runAsync(wallets.load))!.first.balance.decimal,
        '100.00',
      );
      expect(find.text('Cancelled'), findsOneWidget);
      final fees = (await tester.runAsync(
        () => LocalTransactionRepository(db).load(),
      ))!;
      expect(fees.single.deleted, true);
    },
  );
  testWidgets(
    'Arabic mobile exact input and insufficient error preserve balances',
    (tester) async {
      await mount(tester, ar: true);
      await press(tester, 'transfer-add');
      await tester.enterText(
        find.byKey(const ValueKey('transfer-amount')),
        '١٠٠',
      );
      await tester.enterText(
        find.byKey(const ValueKey('transfer-fee')),
        '٠٫٠١',
      );
      await press(tester, 'transfer-save');
      expect(
        find.text('الرصيد لا يكفي لإتمام التحويل أو عكسه.'),
        findsOneWidget,
      );
      expect((await tester.runAsync(transfers.load))!, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('live hiding clears amount fee and masks editor preview', (
    tester,
  ) async {
    await mount(tester);
    await press(tester, 'transfer-add');
    await tester.enterText(
      find.byKey(const ValueKey('transfer-amount')),
      '7.25',
    );
    await tester.enterText(find.byKey(const ValueKey('transfer-fee')), '0.35');
    final all = (await tester.runAsync(wallets.load))!;
    await tester.runAsync(
      () => wallets.setHidden(
        WalletOperation.generate(),
        all.last.wallet.id,
        0,
        true,
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(const ValueKey('transfer-amount')),
          matching: find.byType(TextFormField),
        ),
      );
      if (field.controller!.text.isEmpty) break;
    }
    final input = find.descendant(
      of: find.byKey(const ValueKey('transfer-amount')),
      matching: find.byType(TextFormField),
    );
    expect(tester.widget<TextFormField>(input).controller!.text, isEmpty);
    expect(find.textContaining('7.25'), findsNothing);
    expect(find.text('Amount hidden'), findsWidgets);
  });
  testWidgets('linked fee transaction exposes no enabled edit or delete', (
    tester,
  ) async {
    await mount(tester);
    await press(tester, 'transfer-add');
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '10');
    await tester.enterText(find.byKey(const ValueKey('transfer-fee')), '1');
    await press(tester, 'transfer-save');
    final fee = (await tester.runAsync(
      () => LocalTransactionRepository(db).load(),
    ))!.single;
    final all = (await tester.runAsync(wallets.load))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProviderScope(
            overrides: [
              exchangeRepositoryProvider.overrideWithValue(
                LocalExchangeRepository(db),
              ),
              categoryRepositoryProvider.overrideWithValue(
                LocalCategoryRepository(db),
              ),
            ],
            child: TransactionRow(transaction: fee, wallets: all),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('transaction-edit')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('transaction-delete')))
          .onPressed,
      isNull,
    );
    expect(find.text('Expense · Transfer fee'), findsOneWidget);
  });
  testWidgets('two wallet editor can swap direction and reset foreign quote', (
    tester,
  ) async {
    await mount(tester);
    final id = (await tester.runAsync(
      () => wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Dollars',
          color: 'blue',
          icon: 'bank',
          type: 'bank',
          currency: Currency('USD', 2),
        ),
        Money.parse('50', Currency('USD', 2)),
      ),
    ))!;
    await tester.pumpWidget(const SizedBox());
    final all = (await tester.runAsync(wallets.load))!;
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
          transferRepositoryProvider.overrideWithValue(transfers),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTransferEditor(context, [
                  all.first,
                  all.singleWhere((w) => w.wallet.id == id),
                ]),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '10');
    await tester.enterText(find.byKey(const ValueKey('transfer-rate')), '0.5');
    await press(tester, 'transfer-swap');
    expect(find.text('Transfer amount (USD)'), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const ValueKey('transfer-amount')),
      matching: find.byType(TextFormField),
    );
    expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '2');
    await tester.enterText(find.byKey(const ValueKey('transfer-rate')), '2');
    await press(tester, 'transfer-save');
    expect((await tester.runAsync(transfers.load))!.single.draft.sourceId, id);
    expect(
      (await tester.runAsync(wallets.load))!
          .singleWhere((w) => w.wallet.id == id)
          .balance
          .decimal,
      '48.00',
    );
  });
  testWidgets(
    'refreshing retained wallet data hides and clears transfer editor',
    (tester) async {
      await mount(tester);
      await press(tester, 'transfer-add');
      await tester.enterText(
        find.byKey(const ValueKey('transfer-amount')),
        '7.25',
      );
      await tester.enterText(
        find.byKey(const ValueKey('transfer-fee')),
        '0.35',
      );
      refreshGate = Completer<void>();
      addTearDown(() {
        if (refreshGate != null && !refreshGate!.isCompleted) {
          refreshGate!.complete();
        }
        refreshGate = null;
      });
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransfersPage)),
      );
      container.invalidate(walletsProvider);
      await tester.pump();
      await tester.pump();
      expect(container.read(walletsProvider).isLoading, true);
      final field = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(const ValueKey('transfer-amount')),
          matching: find.byType(TextFormField),
        ),
      );
      expect(field.controller!.text, isEmpty);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('transfer-amount')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        true,
      );
      expect(find.textContaining('7.25'), findsNothing);
      refreshGate!.complete();
      refreshGate = null;
      await tester.pumpAndSettle();
    },
  );
}

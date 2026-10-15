import 'package:kim/features/categories/data/local_category_repository.dart';
import 'package:kim/features/categories/presentation/category_providers.dart';
import 'package:kim/features/budgets/data/local_budget_repository.dart';
import 'package:kim/features/budgets/presentation/budget_providers.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/presentation/transfer_providers.dart';
import 'package:kim/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/app/kim_app.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:kim/features/settings/domain/app_settings.dart';
import 'package:kim/features/settings/presentation/settings_controller.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/presentation/wallet_providers.dart';

void main() {
  Future<LocalWalletRepository> mount(
    WidgetTester tester, {
    bool arabic = false,
    Size size = const Size(1440, 1100),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'wallet-ui.db'),
    ))!;
    addTearDown(db.close);
    final repo = LocalWalletRepository(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            LocalCategoryRepository(db),
          ),
          budgetRepositoryProvider.overrideWithValue(LocalBudgetRepository(db)),
          transferRepositoryProvider.overrideWithValue(
            LocalTransferRepository(db),
          ),
          transactionRepositoryProvider.overrideWithValue(
            LocalTransactionRepository(db),
          ),
          settingsRepositoryProvider.overrideWithValue(
            LocalSettingsRepository(db),
          ),
          initialSettingsProvider.overrideWithValue(
            AppSettings(
              languageCode: arabic ? 'ar' : 'en',
              theme: AppTheme.dark,
            ),
          ),
          walletRepositoryProvider.overrideWithValue(repo),
        ],
        child: const KimApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-wallets')));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> create(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('wallet-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('wallet-name')),
      'Daily cash',
    );
    await tester.enterText(
      find.byKey(const ValueKey('wallet-opening')),
      '١٠٫٢٥',
    );
    await tester.tap(find.byKey(const ValueKey('wallet-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('creates a real wallet and shows its immutable opening history', (
    tester,
  ) async {
    final repo = await mount(tester);
    await create(tester);
    final list = (await tester.runAsync(repo.load))!;
    expect(list.single.balance.decimal, '10.25');
    expect(list.single.entries.length, 1);
    await tester.tap(find.text('Daily cash'));
    await tester.pumpAndSettle();
    expect(find.text('Financial history'), findsOneWidget);
    expect(find.text('Opening balance'), findsOneWidget);
    expect(find.text(list.single.entries.single.operationId), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'metadata editing cannot replace opening and hidden detail masks every amount',
    (tester) async {
      final repo = await mount(tester);
      await create(tester);
      await tester.tap(find.text('Daily cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wallet-edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wallet-opening')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('wallet-name')),
        'Renamed cash',
      );
      await tester.tap(find.byKey(const ValueKey('wallet-save')));
      await tester.pumpAndSettle();
      expect(find.text('Renamed cash'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wallet-hide')));
      await tester.pumpAndSettle();
      expect(find.textContaining('10.25'), findsNothing);
      expect((await tester.runAsync(repo.load))!.single.entries.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Arabic compact create form fits and validates excess precision',
    (tester) async {
      await mount(tester, arabic: true, size: const Size(390, 844));
      await tester.tap(find.byKey(const ValueKey('wallet-create')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('wallet-name')), 'نقد');
      await tester.ensureVisible(find.byKey(const ValueKey('wallet-opening')));
      await tester.enterText(
        find.byKey(const ValueKey('wallet-opening')),
        '1.001',
      );
      await tester.tap(find.byKey(const ValueKey('wallet-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wallet-save')), findsOneWidget);
      expect(
        find.text('أدخل مبلغًا صحيحًا بدقة العملة المختارة.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('live privacy hides and clears an already open adjustment form', (
    tester,
  ) async {
    final repo = await mount(tester);
    await create(tester);
    await tester.tap(find.text('Daily cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-adjust')));
    await tester.pumpAndSettle();
    expect(find.text('Current balance: 10.25 ILS'), findsOneWidget);
    final current = (await tester.runAsync(repo.load))!.single;
    await tester.runAsync(
      () => repo.setHidden(
        WalletOperation.generate(),
        current.wallet.id,
        current.wallet.revision,
        true,
      ),
    );
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 30 && find.text('Current balance: 10.25 ILS').evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Current balance: 10.25 ILS'), findsNothing);
    final field = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const ValueKey('adjust-target')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(field.controller!.text, isEmpty);
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('adjust-target')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.obscureText, true);
  });
}

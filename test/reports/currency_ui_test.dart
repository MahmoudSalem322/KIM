import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/reports/data/local_exchange_repository.dart';
import 'package:kim/features/reports/presentation/currency_management_page.dart';
import 'package:kim/features/reports/presentation/currency_providers.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/presentation/wallet_providers.dart';

void main() {
  late AppDatabase db;
  late LocalExchangeRepository exchange;
  setUp(() async {
    db = await AppDatabase.open(newDatabaseFactoryMemory(), 'currency-ui');
    exchange = LocalExchangeRepository(db);
  });
  tearDown(() async => db.database.close());
  Future<void> mount(WidgetTester t, {String language = 'en'}) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          exchangeRepositoryProvider.overrideWithValue(exchange),
          walletRepositoryProvider.overrideWithValue(LocalWalletRepository(db)),
        ],
        child: MaterialApp(
          locale: Locale(language),
          theme: language == 'ar' ? ThemeData.dark() : ThemeData.light(),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(
            body: SingleChildScrollView(child: CurrencyManagementPage()),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('documented rate saves exact decimal, edits and deletes', (
    t,
  ) async {
    await mount(t);
    await t.tap(find.text('Add exchange rate'));
    await t.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), '3.654321');
    await t.enterText(fields.at(1), 'Manual bank quotation');
    await t.enterText(fields.at(2), '2026-10-20');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect((await t.runAsync(exchange.load))!.rates.single.decimal, '3.654321');
    expect(find.text('1 USD = 3.654321 ILS'), findsOneWidget);
    await t.ensureVisible(find.text('Edit exchange rate'));
    await t.tap(find.text('Edit exchange rate'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), '3.7');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect((await t.runAsync(exchange.load))!.rates.single.decimal, '3.7');
    await t.ensureVisible(find.text('Delete'));
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await t.pumpAndSettle();
    expect((await t.runAsync(exchange.load))!.rates, isEmpty);
  });
  testWidgets('invalid rates stay unsaved and primary currency persists', (
    t,
  ) async {
    await mount(t);
    await t.tap(find.text('Add exchange rate'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), '-1');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Enter a positive decimal rate'),
      findsOneWidget,
    );
    expect((await t.runAsync(exchange.load))!.rates, isEmpty);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<Currency>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('USD · 2').last);
    await t.pumpAndSettle();
    expect((await t.runAsync(exchange.load))!.currency.code, 'USD');
  });
  testWidgets('Arabic dark narrow currency page and editor have no overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await mount(t, language: 'ar');
    expect(
      Directionality.of(t.element(find.text('العملات وأسعار الصرف'))),
      TextDirection.rtl,
    );
    await t.ensureVisible(find.text('إضافة سعر صرف'));
    await t.tap(find.text('إضافة سعر صرف'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}

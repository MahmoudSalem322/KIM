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
import 'package:kim/features/wallets/presentation/wallet_providers.dart';

void main() {
  Future<AppDatabase> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'widget.db'),
    ))!;
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(LocalWalletRepository(db)),
          settingsRepositoryProvider.overrideWithValue(
            LocalSettingsRepository(db),
          ),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(languageCode: 'en'),
          ),
        ],
        child: const KimApp(),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('all registered sections navigate to honest empty states', (
    tester,
  ) async {
    await mount(tester, const Size(1440, 1000));
    for (final entry in {
      'wallets': 'Your wallets, in one place',
      'transactions': 'A clear view of your money',
      'budgets': 'Give every goal a plan',
      'reports': 'See the bigger picture',
    }.entries) {
      await tester.tap(find.byKey(ValueKey('nav-${entry.key}')));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('navigation remains accessible outside the nested navigator', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mount(tester, const Size(1440, 1000));
    expect(find.semantics.byLabel('Wallets'), findsOneWidget);
    expect(find.semantics.byLabel('Settings'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('language and theme update UI and persisted preferences', (
    tester,
  ) async {
    final db = await mount(tester, const Size(1440, 1000));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('language-ar')));
    await tester.tap(find.byKey(const ValueKey('language-ar')));
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsWidgets);
    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey('settings-page'))),
      ),
      TextDirection.rtl,
    );
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('settings-page'))))
          .brightness,
      Brightness.dark,
    );
    final persisted = (await tester.runAsync(
      () => LocalSettingsRepository(db).load(),
    ))!;
    expect(persisted.languageCode, 'ar');
    expect(persisted.theme, AppTheme.dark);
  });
  testWidgets('compact layout navigates and does not overflow in RTL', (
    tester,
  ) async {
    await mount(tester, const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('language-ar')));
    await tester.tap(find.byKey(const ValueKey('language-ar')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('nav-wallets')));
    await tester.pumpAndSettle();
    expect(find.text('محافظك، في مكان واحد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short desktop sidebar and pages scroll without overflow', (
    tester,
  ) async {
    await mount(tester, const Size(1366, 600));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('nav-settings')));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('language-ar')));
    await tester.tap(find.byKey(const ValueKey('language-ar')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

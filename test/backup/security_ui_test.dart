import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/features/security/data/security_repository.dart';
import 'package:kim/features/security/presentation/security_controller.dart';
import 'package:kim/features/security/presentation/security_gate.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:kim/features/settings/domain/app_settings.dart';
import 'package:kim/features/settings/presentation/settings_controller.dart';
import 'package:kim/features/settings/presentation/settings_page.dart';
import 'package:kim/features/backup/data/backup_repository.dart';
import 'package:kim/features/backup/presentation/backup_panel.dart';

void main() {
  late AppDatabase db;
  late SecurityRepository security;
  late ProviderContainer container;
  Future<void> mount(
    WidgetTester t, {
    bool pin = false,
    bool ar = false,
  }) async {
    db = (await t.runAsync(
      () => AppDatabase.open(newDatabaseFactoryMemory(), 'ui'),
    ))!;
    addTearDown(db.close);
    security = SecurityRepository(db);
    if (pin) await t.runAsync(() => security.setPin('123456'));
    container = ProviderContainer(
      overrides: [
        securityRepositoryProvider.overrideWithValue(security),
        settingsRepositoryProvider.overrideWithValue(
          LocalSettingsRepository(db),
        ),
        initialSettingsProvider.overrideWithValue(
          AppSettings(languageCode: ar ? 'ar' : 'en'),
        ),
        backupRepositoryProvider.overrideWithValue(BackupRepository(db)),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(ar ? 'ar' : 'en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) =>
              MaintenanceOverlay(child: SecurityGate(child: child!)),
          home: const Scaffold(
            body: SingleChildScrollView(child: SettingsPage()),
          ),
        ),
      ),
    );
    await drain(t);
  }

  Future<void> enter(WidgetTester t, String key, String value) async {
    await t.enterText(find.byKey(ValueKey(key)), value);
  }

  testWidgets(
    'PIN gate removes app contents, unlocks and relocks on background; removal authenticates',
    (t) async {
      await mount(t, pin: true);
      expect(find.byKey(const ValueKey('settings-page')), findsNothing);
      await enter(t, 'unlock-pin', '000000');
      await t.tap(find.byKey(const ValueKey('unlock-button')));
      await drain(t);
      expect(find.textContaining('Incorrect PIN'), findsOneWidget);
      await enter(t, 'unlock-pin', '123456');
      await t.tap(find.byKey(const ValueKey('unlock-button')));
      await drain(t);
      expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
      container.read(externalFileDialogProvider.notifier).set(true);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(
        container.read(securityControllerProvider).requireValue.unlocked,
        true,
      );
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      container.read(externalFileDialogProvider.notifier).set(false);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(
        container.read(securityControllerProvider).requireValue.unlocked,
        false,
      );
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-page')), findsNothing);
      await enter(t, 'unlock-pin', '123456');
      await t.tap(find.byKey(const ValueKey('unlock-button')));
      await drain(t);
      await t.ensureVisible(find.text('Remove PIN'));
      await t.tap(find.text('Remove PIN'));
      await t.pumpAndSettle();
      await enter(t, 'pin-current', '123456');
      await t.tap(find.byKey(const ValueKey('pin-save')));
      await drain(t);
      expect((await t.runAsync(security.load)), null);
    },
  );
  testWidgets(
    'settings validate matching PIN and encrypted backup password before saving',
    (t) async {
      await mount(t);
      await t.ensureVisible(find.byKey(const ValueKey('pin-configure')));
      await t.tap(find.byKey(const ValueKey('pin-configure')));
      await t.pumpAndSettle();
      await enter(t, 'pin-new', '123');
      await enter(t, 'pin-confirm', '123');
      await t.tap(find.byKey(const ValueKey('pin-save')));
      await t.pumpAndSettle();
      expect(find.textContaining('Use 6'), findsOneWidget);
      await enter(t, 'pin-new', '123456');
      await enter(t, 'pin-confirm', '123456');
      await t.tap(find.byKey(const ValueKey('pin-save')));
      await drain(t);
      expect((await t.runAsync(security.load)), isNotNull);
      await t.ensureVisible(find.text('Encrypt with a password'));
      await t.tap(find.text('Encrypt with a password'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('backup-download')));
      await t.tap(find.byKey(const ValueKey('backup-download')));
      await t.pumpAndSettle();
      expect(find.textContaining('Use matching passwords'), findsOneWidget);
    },
  );
  testWidgets('Arabic narrow security settings and PIN editor remain usable', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await mount(t, ar: true);
    await t.ensureVisible(find.byKey(const ValueKey('pin-configure')));
    await t.tap(find.byKey(const ValueKey('pin-configure')));
    await t.pumpAndSettle();
    expect(find.text('تعيين PIN'), findsWidgets);
    expect(t.takeException(), null);
  });
}

Future<void> drain(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await t.pumpAndSettle();
}

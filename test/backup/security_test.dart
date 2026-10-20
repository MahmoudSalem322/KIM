import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/security/data/security_repository.dart';
import 'package:kim/features/security/presentation/security_controller.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:kim/features/settings/domain/app_settings.dart';
import 'package:kim/features/settings/presentation/settings_controller.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/presentation/wallet_providers.dart';

void main() {
  late AppDatabase db;
  late SecurityRepository security;
  late DateTime clock;
  setUp(() async {
    db = await AppDatabase.open(newDatabaseFactoryMemory(), 'security');
    clock = DateTime.utc(2026, 10, 20);
    security = SecurityRepository(db, now: () => clock);
  });
  tearDown(() async => db.close());
  test('PIN is salted hashed; five failures delay attempts and correct PIN recovers after delay', () async {
    await security.setPin('123456');
    final stored = jsonEncode(await security.load());
    expect(stored, isNot(contains('123456')));
    for (var i = 0; i < 5; i++) {
      expect(await security.verify('000000'), false);
    }
    expect(await security.verify('123456'), false);
    clock = clock.add(const Duration(seconds: 31));
    expect(await security.verify('123456'), true);
    expect((await security.load())!['attempts'], 0);
  });
  test('PIN changes and removal require current PIN, with no replacement on failure', () async {
    await security.setPin('123456');
    await expectLater(
      security.setPin('987654', oldPin: '000000'),
      throwsStateError,
    );
    expect(await security.verify('123456'), true);
    await security.setPin('987654', oldPin: '123456');
    expect(await security.verify('123456'), false);
    expect(await security.verify('987654'), true);
    await expectLater(security.remove('123456'), throwsStateError);
    await security.remove('987654');
    expect(await security.load(), null);
    await expectLater(security.setPin('123'), throwsFormatException);
  });
  test('a new application session starts locked and explicit lock drops authorization', () async {
    await security.setPin('123456');
    final container = ProviderContainer(
      overrides: [securityRepositoryProvider.overrideWithValue(security)],
    );
    addTearDown(container.dispose);
    expect(
      (await container.read(securityControllerProvider.future)).unlocked,
      false,
    );
    expect(
      await container
          .read(securityControllerProvider.notifier)
          .unlock('000000'),
      false,
    );
    expect(
      await container
          .read(securityControllerProvider.notifier)
          .unlock('123456'),
      true,
    );
    container.read(securityControllerProvider.notifier).lock();
    expect(
      container.read(securityControllerProvider).requireValue.unlocked,
      false,
    );
  });
  test(
    'global privacy persists and never overwrites individual wallet privacy',
    () async {
      final wallets = LocalWalletRepository(db), currency = Currency('ILS', 2);
      final a = await wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Visible',
          color: 'blue',
          icon: 'cash',
          type: 'cash',
          currency: currency,
        ),
        Money.parse('100', currency),
      );
      final b = await wallets.create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Hidden',
          color: 'blue',
          icon: 'cash',
          type: 'cash',
          currency: currency,
        ),
        Money.parse('200', currency),
      );
      await wallets.setHidden(WalletOperation.generate(), b, 0, true);
      final settings = LocalSettingsRepository(db);
      final container = ProviderContainer(
        overrides: [
          walletRepositoryProvider.overrideWithValue(wallets),
          settingsRepositoryProvider.overrideWithValue(settings),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
        ],
      );
      addTearDown(container.dispose);
      final keep = container.listen(walletsProvider, (_, _) {});
      addTearDown(keep.close);
      expect(
        (await container.read(walletsProvider.future))
            .singleWhere((w) => w.wallet.id == a)
            .wallet
            .hidden,
        false,
      );
      await container
          .read(settingsControllerProvider.notifier)
          .setHideBalances(true);
      await Future<void>.delayed(Duration.zero);
      expect(
        (await container.read(walletsProvider.future))
            .every((w) => w.wallet.hidden),
        true,
      );
      expect((await settings.load()).hideBalances, true);
      await container
          .read(settingsControllerProvider.notifier)
          .setHideBalances(false);
      await Future<void>.delayed(Duration.zero);
      final restored = await container.read(walletsProvider.future);
      expect(
        restored.singleWhere((w) => w.wallet.id == a).wallet.hidden,
        false,
      );
      expect(restored.singleWhere((w) => w.wallet.id == b).wallet.hidden, true);
    },
  );
}

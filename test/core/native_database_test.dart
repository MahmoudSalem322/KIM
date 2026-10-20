import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kim/core/data/open_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:kim/features/settings/domain/app_settings.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kim-native-');
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getApplicationSupportDirectory');
      return '${directory.path}${Platform.pathSeparator}private';
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });
  test('native bootstrap uses persistent private files and restores exact balances and preferences', () async {
    var db = await openAppDatabase();
    final currency = Currency('ILS', 2);
    await LocalSettingsRepository(db)
        .save(const AppSettings(languageCode: 'en', theme: AppTheme.dark));
    await LocalWalletRepository(db).create(
      WalletOperation.generate(),
      WalletDraft(
        name: 'Phone cash',
        color: 'emerald',
        icon: 'cash',
        type: 'cash',
        currency: currency,
      ),
      Money.parse('9007199254740993.25', currency),
    );
    await db.close();
    expect(
      await File(
        '${directory.path}${Platform.pathSeparator}private${Platform.pathSeparator}mywallet.db',
      ).exists(),
      isTrue,
    );
    db = await openAppDatabase();
    expect(
      (await LocalWalletRepository(db).load()).single.balance.decimal,
      '9007199254740993.25',
    );
    expect((await LocalSettingsRepository(db).load()).languageCode, 'en');
    await db.close();
  });
  test('unavailable native storage surfaces an error rather than silently losing data', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(openAppDatabase(), throwsA(isA<Exception>()));
  });
}

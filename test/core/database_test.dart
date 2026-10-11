import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/operation_id.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:kim/features/settings/domain/app_settings.dart';

void main() {
  late Directory dir;
  late String path;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mywallet_test_');
    path = '${dir.path}/wallet.db';
  });
  tearDown(() async => dir.delete(recursive: true));

  test('preferences survive close and reopen', () async {
    var db = await AppDatabase.open(databaseFactoryIo, path);
    await LocalSettingsRepository(db)
        .save(const AppSettings(languageCode: 'en', theme: AppTheme.dark));
    await db.close();
    db = await AppDatabase.open(databaseFactoryIo, path);
    final restored = await LocalSettingsRepository(db).load();
    expect(restored.languageCode, 'en');
    expect(restored.theme, AppTheme.dark);
    await db.close();
  });
  test('version 1 migration preserves old preferences', () async {
    final old = await databaseFactoryIo.openDatabase(path, version: 1);
    await stringMapStoreFactory.store('settings').record('preferences').put(
      old,
      {'locale': 'en', 'theme': 'dark'},
    );
    await old.close();
    final db = await AppDatabase.open(databaseFactoryIo, path);
    expect(db.database.version, AppDatabase.schemaVersion);
    final restored = await LocalSettingsRepository(db).load();
    expect(restored.languageCode, 'en');
    expect(restored.theme, AppTheme.dark);
    await db.close();
  });
  test('newer database schemas fail rather than destroy data', () async {
    final newer = await databaseFactoryIo.openDatabase(path, version: 99);
    await newer.close();
    await expectLater(
      AppDatabase.open(databaseFactoryIo, path),
      throwsStateError,
    );
  });
  test('atomic duplicate operations execute once, conflict rejected', () async {
    final db = await AppDatabase.open(databaseFactoryIo, path);
    final id = OperationId.generate();
    final store = stringMapStoreFactory.store('test_ledger');
    Future<void> write(Transaction txn) async {
      final current = await store.record('count').get(txn);
      await store.record('count').put(txn, {
        'count': (current?['count'] as int? ?? 0) + 1,
      });
    }

    final results = await Future.wait(
      List.generate(5, (_) => db.applyOnce(id, 'same-request', write)),
    );
    expect(results.where((applied) => applied).length, 1);
    expect((await store.record('count').get(db.database))?['count'], 1);
    await expectLater(
      db.applyOnce(id, 'different-request', write),
      throwsStateError,
    );
    await db.close();
  });
  test(
    'failed operation rolls back write and receipt; retry succeeds',
    () async {
      final db = await AppDatabase.open(databaseFactoryIo, path);
      final store = stringMapStoreFactory.store('test_ledger');
      final id = OperationId.generate();
      await expectLater(
        db.applyOnce(id, 'payload', (txn) async {
          await store.record('entry').put(txn, {'value': 'partial'});
          throw StateError('failure');
        }),
        throwsStateError,
      );
      expect(await store.record('entry').get(db.database), isNull);
      expect(
        await db.applyOnce(id, 'payload', (txn) async {
          await store.record('entry').put(txn, {'value': 'complete'});
        }),
        isTrue,
      );
      await db.close();
    },
  );
}

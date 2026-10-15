import 'package:sembast/sembast.dart';

import '../domain/operation_id.dart';
import '../../features/categories/data/category_schema.dart';

final class AppDatabase {
  AppDatabase._(this.database);
  static const schemaVersion = 8;
  static final settings = stringMapStoreFactory.store('settings');
  static final _receipts = stringMapStoreFactory.store('operation_receipts');
  final Database database;

  static Future<AppDatabase> open(DatabaseFactory factory, String path) async {
    final db = await factory.openDatabase(
      path,
      version: schemaVersion,
      onVersionChanged: (db, oldVersion, newVersion) async {
        if (oldVersion > schemaVersion) {
          throw StateError('Database was created by a newer Kim version');
        }
        // Sembast runs version callbacks in its opening transaction.
        if (oldVersion < 1) {
          await settings.record('preferences').put(db, {
            'locale': 'ar',
            'theme': 'system',
          });
        }
        if (oldVersion < 2) {
          final legacy = await settings.record('preferences').get(db);
          await settings.record('preferences').put(db, {
            'languageCode': legacy?['locale'] ?? 'ar',
            'theme': legacy?['theme'] ?? 'system',
          });
        }
        if (oldVersion < 3) {
          // Wallet stores are created lazily, without fabricated balances.
          await stringMapStoreFactory
              .store('schema')
              .record('walletLedger')
              .put(db, {'version': 1});
        }
        if (oldVersion < 4) {
          await stringMapStoreFactory
              .store('schema')
              .record('transactions')
              .put(db, {'version': 1});
        }
        if (oldVersion < 5) {
          await stringMapStoreFactory.store('schema').record('transfers').put(
            db,
            {'version': 1},
          );
        }
        if (oldVersion < 6) {
          await seedCategories(db);
          await stringMapStoreFactory.store('schema').record('planning').put(
            db,
            {'version': 1},
          );
        }
        if (oldVersion < 7) {
          await stringMapStoreFactory.store('schema').record('savings').put(
            db,
            {'version': 1},
          );
        }
        if (oldVersion < 8) {
          await stringMapStoreFactory.store('schema').record('debts').put(db, {
            'version': 1,
          });
        }
      },
    );
    return AppDatabase._(db);
  }

  /// All effects must be database writes through [transaction], with no network,
  /// notifications or generated IDs in the callback: web transactions can retry.
  /// The caller must retain the operation ID and canonical request across retries.
  Future<bool> applyOnce(
    OperationId id,
    String canonicalRequest,
    Future<void> Function(Transaction transaction) write,
  ) async {
    if (canonicalRequest.isEmpty) {
      throw ArgumentError('Request cannot be empty');
    }
    return database.transaction((txn) async {
      final existing = await _receipts.record(id.value).get(txn);
      if (existing != null) {
        if (existing['request'] != canonicalRequest) {
          throw StateError('Operation ID reused for a different request');
        }
        return false;
      }
      await write(txn);
      await _receipts.record(id.value).put(txn, {'request': canonicalRequest});
      return true;
    });
  }

  Future<void> close() => database.close();
}

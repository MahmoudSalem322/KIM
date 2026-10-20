import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/sembast_import_export.dart';

import '../../../core/data/app_database.dart';
import '../../wallets/data/local_wallet_repository.dart';
import '../../transactions/data/local_transaction_repository.dart';
import '../../transfers/data/local_transfer_repository.dart';
import '../../categories/data/local_category_repository.dart';
import '../../categories/domain/app_category.dart';
import '../../budgets/data/local_budget_repository.dart';
import '../../savings/data/local_savings_repository.dart';
import '../../debts/data/local_debt_repository.dart';
import '../../recurring/data/local_recurring_repository.dart';
import '../../reports/data/local_exchange_repository.dart';
import '../../settings/data/local_settings_repository.dart';
import '../../security/data/security_repository.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/backup_codec.dart';

const backupStores = [
  'settings',
  'schema',
  'operation_receipts',
  'wallets',
  'wallet_entries',
  'transactions',
  'transfers',
  'categories',
  'budgets',
  'savings_goals',
  'savings_events',
  'debts',
  'debt_cash_events',
  'recurring_payments',
  'recurring_occurrences',
  'report_exchange',
  'notification_state',
  'security',
];
Object? _ordered(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _ordered(value[k])};
  }
  if (value is List) return value.map(_ordered).toList();
  return value;
}

String canonicalBackup(Object? value) => jsonEncode(_ordered(value));

class ValidatedBackup {
  ValidatedBackup._(
    this._snapshot,
    this.createdAt,
    this.sourceVersion,
    this.records,
    this.hasPin,
  );
  final String _snapshot;
  final DateTime createdAt;
  final int sourceVersion, records;
  final bool hasPin;
}

class RestorePreview {
  RestorePreview._(this.backup, this._current);
  final ValidatedBackup backup;
  final String _current;
}

class BackupRepository {
  BackupRepository(this.db);
  final AppDatabase db;
  static final recovery = stringMapStoreFactory.store('backup_recovery');
  Future<Map<String, Object?>> _snapshot(DatabaseClient client) async {
    final stores = <Map<String, Object?>>[];
    for (final name in [...backupStores]..sort()) {
      final rows = await stringMapStoreFactory.store(name).find(client);
      rows.sort((a, b) => a.key.compareTo(b.key));
      if (rows.isNotEmpty) {
        stores.add({
          'name': name,
          'keys': rows.map((r) => r.key).toList(),
          'values': rows.map((r) => r.value).toList(),
        });
      }
    }
    return {
      'sembast_export': 1,
      'version': AppDatabase.schemaVersion,
      'stores': stores,
    };
  }

  Future<Map<String, Object?>> snapshot() => db.database.transaction(_snapshot);
  Future<Uint8List> create({String? password}) async => BackupCodec.encode({
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'database': await snapshot(),
  }, password: password);
  Future<ValidatedBackup> inspect(Uint8List bytes, {String? password}) async =>
      validate(await BackupCodec.decode(bytes, password: password));
  Future<ValidatedBackup> validate(Map<String, Object?> payload) async {
    final created = DateTime.parse(payload['createdAt'] as String);
    final raw = Map<String, Object?>.from(payload['database'] as Map),
        version = raw['version'];
    if (raw['sembast_export'] != 1 ||
        version is! int ||
        version < 8 ||
        version > AppDatabase.schemaVersion) {
      throw const FormatException('Unsupported data version');
    }
    final names = <String>{};
    var count = 0;
    for (final item in raw['stores'] as List) {
      final row = item as Map, name = row['name'] as String;
      if (!backupStores.contains(name) || !names.add(name)) {
        throw const FormatException('Unknown or duplicate store');
      }
      final keys = row['keys'] as List, values = row['values'] as List;
      if (keys.length != values.length ||
          keys.toSet().length != keys.length ||
          keys.any((k) => k is! String || k.isEmpty || k.length > 300) ||
          values.any((v) => v is! Map)) {
        throw const FormatException('Invalid records');
      }
      count += keys.length;
    }
    if (count > 100000) throw const FormatException('Too many records');
    final factory = newDatabaseFactoryMemory();
    final imported = await importDatabase(raw, factory, 'validation');
    await imported.close();
    final staged = await AppDatabase.open(factory, 'validation');
    try {
      await _validateRelations(staged);
      final upgraded = await BackupRepository(staged).snapshot();
      return ValidatedBackup._(
        canonicalBackup(upgraded),
        created,
        version,
        count,
        await SecurityRepository(staged).load() != null,
      );
    } finally {
      await staged.close();
    }
  }

  Future<RestorePreview> preview(ValidatedBackup backup) async =>
      RestorePreview._(backup, canonicalBackup(await snapshot()));
  Future<ValidatedBackup?> previous() async {
    final record = await recovery.record('previous').get(db.database);
    return record == null
        ? null
        : validate(Map<String, Object?>.from(record['payload'] as Map));
  }

  /// Validation precedes mutation. Every store, the recovery copy and restore ID
  /// commit together; concurrent writes invalidate the user-reviewed preview.
  Future<void> restore(
    RestorePreview preview,
    String operationId, {
    Future<void> Function(Transaction)? beforeCommit,
  }) async {
    if (operationId.isEmpty) {
      throw ArgumentError('Restore operation ID required');
    }
    final incoming = jsonDecode(preview.backup._snapshot) as Map;
    final request = base64Encode(
      (await Sha256().hash(
        utf8.encode('${preview.backup._snapshot}\n${preview._current}'),
      )).bytes,
    );
    final at = DateTime.now().toUtc().toIso8601String();
    await db.database.transaction((txn) async {
      final receipt = await recovery.record('receipt:$operationId').get(txn);
      if (receipt != null) {
        if (receipt['request'] != request) {
          throw StateError('Restore ID reused');
        }
        return;
      }
      final current = await _snapshot(txn);
      if (canonicalBackup(current) != preview._current) {
        throw StateError('Workspace changed; review again');
      }
      await recovery.record('previous').put(txn, {
        'payload': {'createdAt': at, 'database': current},
      });
      for (final name in backupStores) {
        await stringMapStoreFactory.store(name).delete(txn);
      }
      for (final item in incoming['stores'] as List) {
        final row = item as Map;
        final keys = row['keys'] as List, values = row['values'] as List;
        final store = stringMapStoreFactory.store(row['name'] as String);
        for (var i = 0; i < keys.length; i++) {
          await store
              .record(keys[i] as String)
              .put(txn, Map<String, Object?>.from(values[i] as Map));
        }
      }
      await recovery.record('receipt:$operationId').put(txn, {
        'request': request,
        'at': at,
      });
      if (beforeCommit != null) await beforeCommit(txn);
    });
  }

  Future<void> _validateRelations(AppDatabase staged) async {
    final wallets = await LocalWalletRepository(staged).load(),
        transactions = await LocalTransactionRepository(staged).load(),
        transfers = await LocalTransferRepository(staged).load(),
        categories = await LocalCategoryRepository(staged).load(),
        budgets = await LocalBudgetRepository(staged).load(),
        goals = await LocalSavingsRepository(staged).load(),
        debts = await LocalDebtRepository(staged).load();
    final recurring = LocalRecurringRepository(staged),
        plans = await recurring.load(),
        occurrences = await recurring.occurrences();
    final ids = {for (final w in wallets) w.wallet.id: w};
    final cats = {for (final c in categories) c.id: c};
    if (!defaultCategories().every((c) => cats.containsKey(c.id))) {
      throw const FormatException('Missing built-in category');
    }
    void wallet(String id) {
      if (!ids.containsKey(id)) throw const FormatException('Missing wallet');
    }

    for (final w in wallets) {
      w.wallet.draft.validate();
    }
    for (final t in transactions) {
      wallet(t.walletId);
      t.draft.validate();
      if (t.draft.amount.currency != ids[t.walletId]!.wallet.currency) {
        throw const FormatException('Currency mismatch');
      }
      if (t.linkedTransferId.isNotEmpty &&
          !transfers.any((f) => f.id == t.linkedTransferId)) {
        throw const FormatException('Missing transfer');
      }
    }
    final allEntries = await LocalWalletRepository.entries.find(
      staged.database,
    );
    final eventIds = {
      for (final d in debts)
        for (final e in d.events) e.id,
    };
    for (final row in allEntries) {
      final e = WalletEntry.fromJson(row.key, row.value);
      wallet(e.walletId);
      if (e.transactionId.isNotEmpty &&
              !transactions.any((t) => t.id == e.transactionId) ||
          e.transferId.isNotEmpty &&
              !transfers.any((t) => t.id == e.transferId) ||
          e.debtEventId.isNotEmpty && !eventIds.contains(e.debtEventId)) {
        throw const FormatException('Orphan ledger entry');
      }
    }
    for (final t in transfers) {
      wallet(t.draft.sourceId);
      wallet(t.draft.destinationId);
      t.draft.validate();
    }
    for (final c in categories) {
      c.draft.validate(builtin: c.builtin);
    }
    for (final b in budgets) {
      b.draft.validate();
      if (b.draft.category.isNotEmpty && !cats.containsKey(b.draft.category)) {
        throw const FormatException('Missing category');
      }
    }
    for (final g in goals) {
      for (final e in g.events) {
        wallet(e.walletId);
      }
    }
    final cash = await LocalDebtRepository.cashStore.find(staged.database);
    for (final e in cash) {
      if (!eventIds.contains(e.key)) {
        throw const FormatException('Orphan debt event');
      }
    }
    for (final d in debts) {
      d.debt.draft.validate();
      for (final e in d.events) {
        wallet(e.draft.walletId);
      }
    }
    for (final p in plans) {
      p.draft.validate();
      wallet(p.draft.walletId);
      if (p.draft.amount.currency != ids[p.draft.walletId]!.wallet.currency ||
          !cats.containsKey(p.draft.category)) {
        throw const FormatException('Recurring relationship');
      }
    }
    for (final o in occurrences) {
      if (!plans.any((p) => p.id == o.scheduleId) ||
          !transactions.any((t) => t.id == o.transactionId) ||
          o.id != '${o.scheduleId}:${o.date}') {
        throw const FormatException('Occurrence relationship');
      }
    }
    await LocalExchangeRepository(staged).load();
    final settings = await AppDatabase.settings
        .record('preferences')
        .get(staged.database);
    if (settings == null ||
        !['ar', 'en'].contains(settings['languageCode']) ||
        !['system', 'light', 'dark'].contains(settings['theme']) ||
        (settings.containsKey('hideBalances') &&
            settings['hideBalances'] is! bool)) {
      throw const FormatException('Invalid settings');
    }
    await LocalSettingsRepository(staged).load();
    final security = await SecurityRepository(staged).load();
    if (security != null) {
      if (security['version'] != 1 ||
          base64Decode(security['salt'] as String).length != 16 ||
          base64Decode(security['hash'] as String).length != 32 ||
          (security['attempts'] as int) < 0) {
        throw const FormatException('Invalid PIN metadata');
      }
      if (security['blockedUntil'] != null) {
        DateTime.parse(security['blockedUntil'] as String);
      }
    }
    final securityRows = await SecurityRepository.store.find(staged.database);
    if (securityRows.any((r) => r.key != 'pin')) {
      throw const FormatException('Unknown security record');
    }
    for (final row
        in await stringMapStoreFactory
            .store('operation_receipts')
            .find(staged.database)) {
      final request = row.value['request'];
      if (request is! String ||
          request.isEmpty ||
          jsonDecode(request) is! List) {
        throw const FormatException('Invalid operation receipt');
      }
    }
    for (final row
        in await stringMapStoreFactory
            .store('notification_state')
            .find(staged.database)) {
      for (final entry in row.value.entries) {
        if (['read', 'dismissed', 'enabled', 'sent'].contains(entry.key)) {
          if (entry.value is! bool) {
            throw const FormatException('Invalid notification state');
          }
        } else if (entry.key == 'id') {
          if (entry.value is! int ||
              (entry.value as int) < 1 ||
              (entry.value as int) >= 0x7fffffff) {
            throw const FormatException('Invalid notification ID');
          }
        } else {
          throw const FormatException('Unknown notification state');
        }
      }
    }
  }
}

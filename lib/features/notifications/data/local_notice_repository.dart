import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../../../core/data/app_database.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/notice.dart';

final class LocalNoticeRepository {
  LocalNoticeRepository(this.db);
  final AppDatabase db;
  static final store = stringMapStoreFactory.store('notification_state');
  Future<NoticePreferences> load() async {
    final rows = await store.find(db.database);
    return NoticePreferences(
      enabled: rows.any(
        (r) => r.key == 'preferences' && r.value['enabled'] == true,
      ),
      read: {
        for (final r in rows)
          if (r.value['read'] == true) r.key,
      },
      dismissed: {
        for (final r in rows)
          if (r.value['dismissed'] == true) r.key,
      },
    );
  }

  Stream<NoticePreferences> watch() => store
      .query()
      .onSnapshots(db.database)
      .asyncMap((_) => load())
      .distinct(
        (a, b) =>
            a.enabled == b.enabled &&
            a.read.length == b.read.length &&
            a.read.containsAll(b.read) &&
            a.dismissed.length == b.dismissed.length &&
            a.dismissed.containsAll(b.dismissed),
      );
  Future<void> setFlag(
    WalletOperation op,
    String id,
    String flag,
    bool value,
  ) async {
    if (!['read', 'dismissed', 'enabled'].contains(flag)) {
      throw ArgumentError('Invalid flag');
    }
    await db.applyOnce(op.id, jsonEncode(['notice-v1', id, flag, value]), (
      txn,
    ) async {
      final old = await store.record(id).get(txn);
      await store.record(id).put(txn, {...?old, flag: value});
    });
  }

  Future<bool> claim(String key) => db.database.transaction((txn) async {
    final id = 'delivered:$key';
    if (await store.record(id).exists(txn)) return false;
    await store.record(id).put(txn, {'sent': true});
    return true;
  });
  Future<void> release(String key) async {
    await store.record('delivered:$key').delete(db.database);
  }

  Future<int> nativeId(String key) => db.database.transaction((txn) async {
    final id = 'native:$key', old = await store.record(id).get(txn);
    if (old != null) return old['id'] as int;
    final counter = await store.record('nativeCounter').get(txn),
        next = (counter?['id'] as int? ?? 0) + 1;
    if (next >= 0x7fffffff) throw StateError('Notification ID limit');
    await store.record(id).put(txn, {'id': next});
    await store.record('nativeCounter').put(txn, {'id': next});
    return next;
  });
}

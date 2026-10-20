import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../../../core/data/app_database.dart';
import '../../../core/security/password_crypto.dart';

class SecurityRepository {
  SecurityRepository(this.db, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() now;
  static final store = stringMapStoreFactory.store('security');
  Future<Map<String, Object?>?> load() => store.record('pin').get(db.database);
  Future<bool> verify(String pin) async {
    final current = await load();
    if (current == null) return false;
    final blocked = current['blockedUntil'] as String?;
    if (blocked != null && now().toUtc().isBefore(DateTime.parse(blocked))) {
      return false;
    }
    final hash = await (await deriveKey(
      pin,
      base64Decode(current['salt'] as String),
      iterations: 120000,
    )).extractBytes();
    final expected = base64Decode(current['hash'] as String);
    var difference = hash.length ^ expected.length;
    for (var i = 0; i < hash.length && i < expected.length; i++) {
      difference |= hash[i] ^ expected[i];
    }
    final valid = difference == 0;
    return db.database.transaction((txn) async {
      final latest = await store.record('pin').get(txn);
      if (jsonEncode(latest) != jsonEncode(current)) return false;
      final attempts = valid ? 0 : (current['attempts'] as int? ?? 0) + 1;
      await store.record('pin').put(txn, {
        ...current,
        'attempts': attempts,
        'blockedUntil': !valid && attempts >= 5
            ? now().toUtc().add(const Duration(seconds: 30)).toIso8601String()
            : null,
      });
      return valid;
    });
  }

  Future<void> setPin(String pin, {String? oldPin}) async {
    if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain 6 to 12 digits');
    }
    final original = await load();
    if (original != null && (oldPin == null || !await verify(oldPin))) {
      throw StateError('PIN verification failed');
    }
    final expected = await load(), salt = secureBytes(16);
    if (expected?['hash'] != original?['hash']) {
      throw StateError('Security changed');
    }
    final hash = await (await deriveKey(
      pin,
      salt,
      iterations: 120000,
    )).extractBytes();
    await db.database.transaction((txn) async {
      if (jsonEncode(await store.record('pin').get(txn)) !=
          jsonEncode(expected)) {
        throw StateError('Security changed');
      }
      await store.record('pin').put(txn, {
        'version': 1,
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
        'attempts': 0,
        'blockedUntil': null,
      });
    });
  }

  Future<void> remove(String pin) async {
    final original = await load();
    if (!await verify(pin)) throw StateError('PIN verification failed');
    final expected = await load();
    if (expected?['hash'] != original?['hash']) {
      throw StateError('Security changed');
    }
    await db.database.transaction((txn) async {
      if (jsonEncode(await store.record('pin').get(txn)) !=
          jsonEncode(expected)) {
        throw StateError('Security changed');
      }
      await store.record('pin').delete(txn);
    });
  }
}

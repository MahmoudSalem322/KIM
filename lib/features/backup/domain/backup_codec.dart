import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/security/password_crypto.dart';

/// The digest detects corruption, not a maliciously rewritten plaintext file.
abstract final class BackupCodec {
  static const maxFileBytes = 32 * 1024 * 1024;
  static const aad =
      'Kim backup / format 1 / AES-256-GCM / PBKDF2-SHA256-210000';
  static Future<Uint8List> encode(
    Map<String, Object?> payload, {
    String? password,
  }) async {
    final text = jsonEncode(payload),
        digest = base64Encode((await Sha256().hash(utf8.encode(text))).bytes);
    final content = utf8.encode(
      jsonEncode({'payload': text, 'sha256': digest}),
    );
    Map<String, Object?> envelope = {
      'app': 'Kim',
      'format': 1,
      'encrypted': password != null,
    };
    if (password == null) {
      envelope['content'] = utf8.decode(content);
    } else {
      if (password.length < 10 || password.length > 4096) {
        throw const FormatException('Password length must be 10 to 4096');
      }
      final salt = secureBytes(16),
          nonce = secureBytes(12),
          key = await deriveKey(password, salt);
      final box = await AesGcm.with256bits().encrypt(
        content,
        secretKey: key,
        nonce: nonce,
        aad: utf8.encode(aad),
      );
      envelope.addAll({
        'kdf': 'PBKDF2-SHA256',
        'iterations': 210000,
        'cipher': 'AES-256-GCM',
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(box.cipherText),
        'tag': base64Encode(box.mac.bytes),
      });
    }
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    if (bytes.length > maxFileBytes) {
      throw const FormatException('Backup exceeds 32 MiB');
    }
    return bytes;
  }

  static Future<Map<String, Object?>> decode(
    Uint8List bytes, {
    String? password,
  }) async {
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw const FormatException('Backup size');
    }
    final e = jsonDecode(utf8.decode(bytes)) as Map;
    if (e['app'] != 'Kim' || e['format'] != 1 || e['encrypted'] is! bool) {
      throw const FormatException('Unsupported backup format');
    }
    String content;
    if (e['encrypted'] == false) {
      content = e['content'] as String;
    } else {
      if (password == null ||
          password.length > 4096 ||
          e['kdf'] != 'PBKDF2-SHA256' ||
          e['iterations'] != 210000 ||
          e['cipher'] != 'AES-256-GCM') {
        throw const FormatException('Encryption metadata');
      }
      final salt = base64Decode(e['salt'] as String),
          nonce = base64Decode(e['nonce'] as String),
          tag = base64Decode(e['tag'] as String);
      if (salt.length != 16 || nonce.length != 12 || tag.length != 16) {
        throw const FormatException('Encryption metadata');
      }
      content = utf8.decode(
        await AesGcm.with256bits().decrypt(
          SecretBox(
            base64Decode(e['ciphertext'] as String),
            nonce: nonce,
            mac: Mac(tag),
          ),
          secretKey: await deriveKey(password, salt),
          aad: utf8.encode(aad),
        ),
      );
    }
    final checked = jsonDecode(content) as Map,
        text = checked['payload'] as String;
    if (base64Encode((await Sha256().hash(utf8.encode(text))).bytes) !=
        checked['sha256']) {
      throw const FormatException('Checksum mismatch');
    }
    return Map<String, Object?>.from(jsonDecode(text) as Map);
  }
}

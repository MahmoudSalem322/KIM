import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

List<int> secureBytes(int length) {
  final random = Random.secure();
  return List.generate(length, (_) => random.nextInt(256));
}

Future<SecretKey> deriveKey(
  String password,
  List<int> salt, {
  int iterations = 210000,
}) => Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: iterations,
  bits: 256,
).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

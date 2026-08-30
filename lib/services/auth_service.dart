import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class AuthService {
  static const int _iterations = 100000;
  static const int _keyLength = 32; // 256 bits

  static String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  static String hashPassword(String password, String salt) {
    final saltBytes = base64Decode(salt);
    final passwordBytes = utf8.encode(password);

    final params = Pbkdf2Parameters(saltBytes, _iterations, _keyLength);
    final keyDerivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    keyDerivator.init(params);

    final key = keyDerivator.process(Uint8List.fromList(passwordBytes));
    return base64Encode(key);
  }

  static bool verifyPassword(String plaintext, String storedHash, String salt) {
    final computedHash = hashPassword(plaintext, salt);
    if (computedHash.length != storedHash.length) return false;
    int diff = 0;
    for (int i = 0; i < computedHash.length; i++) {
      diff |= computedHash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}

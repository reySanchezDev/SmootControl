import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Creates and validates hashes for local POS access PINs.
final class LocalPinHasher {
  /// Creates a local PIN hasher.
  const LocalPinHasher();

  static const _saltBytes = 16;

  /// Generates a new random salt.
  String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltBytes, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Hashes one PIN using the provided salt.
  String hashPin({required String pin, required String salt}) {
    final digest = sha256.convert(utf8.encode('$salt:$pin'));
    return digest.toString();
  }

  /// Validates one PIN against a stored salt and hash.
  bool verify({
    required String pin,
    required String salt,
    required String hash,
  }) {
    final computed = hashPin(pin: pin, salt: salt);
    return _constantTimeEquals(computed, hash);
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;

    var difference = 0;
    for (var index = 0; index < left.length; index += 1) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }
}

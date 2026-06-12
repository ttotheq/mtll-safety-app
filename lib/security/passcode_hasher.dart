import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'kdf_params.dart';
import 'key_provider.dart';

/// EXECUTION-PLAN §6.5.2 — User.local_passcode_hash stores
/// Argon2id(PIN, user_specific_salt), distinct from the database key
/// derivation. Encoded in a PHC-style string so parameters and salt travel
/// with the hash:
///
///   `argon2id$v=19$m=<KiB>,t=<iters>,p=<lanes>$<salt b64>$<hash b64>`
class PasscodeHasher {
  PasscodeHasher({KdfParams? params, Random? random})
    : params =
          params ??
          // OWASP interactive-login posture; the §6.1.1 64 MiB floor applies
          // to the database master key, not the per-login passcode check.
          const KdfParams(memoryKiB: 19 * 1024, iterations: 2, parallelism: 1),
      _random = random ?? Random.secure();

  static const saltLength = 16;

  final KdfParams params;
  final Random _random;

  String hash(String passcode) {
    final salt = Uint8List.fromList(
      List.generate(saltLength, (_) => _random.nextInt(256)),
    );
    final digest = deriveArgon2idKey(
      passcode: passcode,
      salt: salt,
      params: params,
    );
    return 'argon2id\$v=19'
        '\$m=${params.memoryKiB},t=${params.iterations},p=${params.parallelism}'
        '\$${base64Encode(salt)}'
        '\$${base64Encode(digest)}';
  }

  bool verify(String passcode, String encoded) {
    final parts = encoded.split(r'$');
    if (parts.length != 5 || parts[0] != 'argon2id') {
      return false;
    }

    final options = {
      for (final pair in parts[2].split(','))
        pair.split('=').first: int.tryParse(pair.split('=').last),
    };
    final memoryKiB = options['m'];
    final iterations = options['t'];
    final parallelism = options['p'];
    if (memoryKiB == null || iterations == null || parallelism == null) {
      return false;
    }

    final salt = base64Decode(parts[3]);
    final expected = base64Decode(parts[4]);
    final actual = deriveArgon2idKey(
      passcode: passcode,
      salt: salt,
      params: KdfParams(
        memoryKiB: memoryKiB,
        iterations: iterations,
        parallelism: parallelism,
        outputLength: expected.length,
      ),
    );

    return _constantTimeEquals(actual, expected);
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

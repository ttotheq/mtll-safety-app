import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/security/kdf_params.dart';
import 'package:mtll_safety_app/security/passcode_hasher.dart';

void main() {
  final hasher = PasscodeHasher(
    params: const KdfParams(memoryKiB: 64, iterations: 1, parallelism: 1),
  );

  group('PasscodeHasher', () {
    test('hash verifies the original passcode and rejects others', () {
      final encoded = hasher.hash('482913');

      expect(encoded, startsWith(r'argon2id$v=19$'));
      expect(hasher.verify('482913', encoded), isTrue);
      expect(hasher.verify('482914', encoded), isFalse);
    });

    test('two hashes of the same PIN differ by salt but both verify', () {
      final first = hasher.hash('482913');
      final second = hasher.hash('482913');

      expect(first, isNot(second));
      expect(hasher.verify('482913', first), isTrue);
      expect(hasher.verify('482913', second), isTrue);
    });

    test('verify rejects malformed encodings', () {
      expect(hasher.verify('482913', 'not-a-phc-string'), isFalse);
      expect(hasher.verify('482913', r'argon2id$v=19$m=64,t=1$x$y'), isFalse);
    });

    test('verify honors parameters embedded in the encoding', () {
      // A hash produced with different params still verifies because the
      // PHC string carries m/t/p.
      final other = PasscodeHasher(
        params: const KdfParams(memoryKiB: 128, iterations: 2, parallelism: 1),
      );
      final encoded = other.hash('482913');

      expect(hasher.verify('482913', encoded), isTrue);
    });
  });
}

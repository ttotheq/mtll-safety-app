import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/security/master_key_holder.dart';

void main() {
  group('MasterKeyHolder', () {
    test('holds a key and exposes the live buffer', () {
      final holder = MasterKeyHolder();
      final key = Uint8List.fromList(List.generate(32, (i) => i + 1));

      holder.set(key);

      expect(holder.hasKey, isTrue);
      expect(holder.key, same(key));
    });

    test('zero() overwrites the buffer bytes and drops the key', () {
      final holder = MasterKeyHolder();
      final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
      holder.set(key);

      holder.zero();

      expect(key.every((byte) => byte == 0), isTrue);
      expect(holder.hasKey, isFalse);
      expect(() => holder.key, throwsStateError);
    });

    test('set() zeroes any previously held key', () {
      final holder = MasterKeyHolder();
      final first = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final second = Uint8List.fromList(List.generate(32, (i) => 100 + i));
      holder.set(first);

      holder.set(second);

      expect(first.every((byte) => byte == 0), isTrue);
      expect(holder.key, same(second));
    });

    test('zero() is idempotent when no key is held', () {
      final holder = MasterKeyHolder();

      expect(holder.zero, returnsNormally);
      expect(holder.hasKey, isFalse);
    });
  });
}

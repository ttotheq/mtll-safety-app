import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/security/kdf_params.dart';
import 'package:mtll_safety_app/security/key_provider.dart';
import 'package:mtll_safety_app/security/secure_store.dart';

// Small parameters keep pure-Dart Argon2id fast in tests; production uses
// KdfParams.floor (64 MiB) upward.
const _testParams = KdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);

class InMemorySecureStore implements SecureStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late InMemorySecureStore store;
  late LocalKeystoreKeyProvider provider;

  setUp(() {
    store = InMemorySecureStore();
    provider = LocalKeystoreKeyProvider(
      store: store,
      defaultParams: _testParams,
    );
  });

  group('LocalKeystoreKeyProvider', () {
    test(
      'first derive creates and persists a 32-byte salt and KDF params',
      () async {
        final key = await provider.deriveKey(
          passcode: '482913',
          leagueFileStem: 'league-a',
        );

        expect(key, hasLength(32));
        expect(store.values.keys, {
          LocalKeystoreKeyProvider.saltKey('league-a'),
          LocalKeystoreKeyProvider.kdfParamsKey('league-a'),
        });

        final salt = base64Decode(
          store.values[LocalKeystoreKeyProvider.saltKey('league-a')]!,
        );
        expect(salt, hasLength(LocalKeystoreKeyProvider.saltLength));

        final params = KdfParams.decode(
          store.values[LocalKeystoreKeyProvider.kdfParamsKey('league-a')]!,
        );
        expect(params, _testParams);
      },
    );

    test(
      'derivation is deterministic for the same passcode and salt',
      () async {
        final first = await provider.deriveKey(
          passcode: '482913',
          leagueFileStem: 'league-a',
        );
        final second = await provider.deriveKey(
          passcode: '482913',
          leagueFileStem: 'league-a',
        );

        expect(second, first);
      },
    );

    test('a different passcode produces a different key', () async {
      final first = await provider.deriveKey(
        passcode: '482913',
        leagueFileStem: 'league-a',
      );
      final second = await provider.deriveKey(
        passcode: '482914',
        leagueFileStem: 'league-a',
      );

      expect(second, isNot(first));
    });

    test('each league file stem gets its own salt and key', () async {
      final keyA = await provider.deriveKey(
        passcode: '482913',
        leagueFileStem: 'league-a',
      );
      final keyB = await provider.deriveKey(
        passcode: '482913',
        leagueFileStem: 'league-b',
      );

      expect(keyB, isNot(keyA));
      expect(
        store.values[LocalKeystoreKeyProvider.saltKey('league-a')],
        isNot(store.values[LocalKeystoreKeyProvider.saltKey('league-b')]),
      );
    });

    test('neither the passcode nor the derived key is ever stored', () async {
      const passcode = '482913';
      final key = await provider.deriveKey(
        passcode: passcode,
        leagueFileStem: 'league-a',
      );

      final keyEncodings = {base64Encode(key), hex(key)};
      for (final stored in store.values.values) {
        expect(stored.contains(passcode), isFalse);
        expect(keyEncodings.contains(stored), isFalse);
      }
    });
  });

  group('deriveArgon2idKey', () {
    test('honors the configured output length', () {
      final key = deriveArgon2idKey(
        passcode: '482913',
        salt: base64Decode('AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8='),
        params: const KdfParams(
          memoryKiB: 64,
          iterations: 1,
          parallelism: 1,
          outputLength: 16,
        ),
      );

      expect(key, hasLength(16));
    });
  });
}

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/argon2_native_int_impl.dart';

import 'kdf_params.dart';
import 'secure_store.dart';

/// EXECUTION-PLAN §6.1.6 — KeyProvider abstraction so
/// [LocalKeystoreKeyProvider] (v1) and a future RemoteKmsKeyProvider
/// (v2 cloud KMS) are drop-in swaps. No KMS-specific code ships in v1.
abstract class KeyProvider {
  /// Derives the 32-byte SQLCipher master key for one league database.
  /// The key is never stored; the caller owns the returned buffer and must
  /// zero it when done (§6.1.3).
  Future<Uint8List> deriveKey({
    required String passcode,
    required String leagueFileStem,
  });
}

/// §6.1.1 — local keystore implementation: a per-league random 32-byte salt
/// and tuned Argon2id parameters live in the platform keystore; the passcode
/// and the derived key never touch disk.
class LocalKeystoreKeyProvider implements KeyProvider {
  LocalKeystoreKeyProvider({
    required this._store,
    this._defaultParams = KdfParams.floor,
    Random? random,
  }) : _random = random ?? Random.secure();

  static const saltLength = 32;

  final SecureStore _store;
  final KdfParams _defaultParams;
  final Random _random;

  /// §6.1.1 step 1 — keystore key for the per-league salt.
  static String saltKey(String leagueFileStem) => 'db_salt_$leagueFileStem';

  /// §6.1.1 step 2 — keystore key for the tuned KDF parameters (JSON).
  static String kdfParamsKey(String leagueFileStem) =>
      'db_kdf_params_$leagueFileStem';

  @override
  Future<Uint8List> deriveKey({
    required String passcode,
    required String leagueFileStem,
  }) async {
    final salt = await _loadOrCreateSalt(leagueFileStem);
    final params = await _loadOrStoreParams(leagueFileStem);
    return deriveArgon2idKey(passcode: passcode, salt: salt, params: params);
  }

  Future<Uint8List> _loadOrCreateSalt(String leagueFileStem) async {
    final stored = await _store.read(saltKey(leagueFileStem));
    if (stored != null) {
      return base64Decode(stored);
    }

    final salt = Uint8List.fromList(
      List.generate(saltLength, (_) => _random.nextInt(256)),
    );
    await _store.write(saltKey(leagueFileStem), base64Encode(salt));
    return salt;
  }

  Future<KdfParams> _loadOrStoreParams(String leagueFileStem) async {
    final stored = await _store.read(kdfParamsKey(leagueFileStem));
    if (stored != null) {
      return KdfParams.decode(stored);
    }

    await _store.write(kdfParamsKey(leagueFileStem), _defaultParams.encode());
    return _defaultParams;
  }
}

/// §6.1.1 step 2 — Argon2id derivation of the SQLCipher master key.
/// pointycastle's Argon2 takes memory in KiB; version 1.3.
Uint8List deriveArgon2idKey({
  required String passcode,
  required Uint8List salt,
  required KdfParams params,
}) {
  final generator = Argon2BytesGenerator()
    ..init(
      Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        salt,
        desiredKeyLength: params.outputLength,
        iterations: params.iterations,
        memory: params.memoryKiB,
        lanes: params.parallelism,
        version: Argon2Parameters.ARGON2_VERSION_13,
      ),
    );

  final key = Uint8List(params.outputLength);
  generator.deriveKey(Uint8List.fromList(utf8.encode(passcode)), 0, key, 0);
  return key;
}

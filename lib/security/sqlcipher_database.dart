import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/common.dart';

/// EXECUTION-PLAN §6.1.1 step 3 — the derived key is passed to SQLCipher as
/// a raw 32-byte hex key ("x'…'") so SQLCipher uses it directly without an
/// additional KDF round (the Argon2id derivation in key_provider.dart is the
/// KDF of record).
String sqlcipherKeyPragma(Uint8List key) =>
    'PRAGMA key = "x\'${hexEncode(key)}\'";';

/// §6.1.5 step 3 — key rotation after a PIN change.
String sqlcipherRekeyPragma(Uint8List newKey) =>
    'PRAGMA rekey = "x\'${hexEncode(newKey)}\'";';

String hexEncode(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Applies the key pragma immediately after a connection is established.
void applySqlcipherKey(CommonDatabase database, Uint8List key) {
  database.execute(sqlcipherKeyPragma(key));
}

/// Rotates the database to [newKey]; the connection must already be keyed
/// with the old key (§6.1.5).
void rekeySqlcipherDatabase(CommonDatabase database, Uint8List newKey) {
  database.execute(sqlcipherRekeyPragma(newKey));
}

/// Drift executor over an encrypted league database file
/// (`<app-data>/leagues/<league_uuid>/db.enc`). The SQLCipher dynamic
/// library must be registered with package:sqlite3 before first use
/// (sqlcipher_flutter_libs in the app; an explicit override in tests).
QueryExecutor openEncryptedDatabase({
  required File file,
  required Uint8List key,
}) {
  return NativeDatabase(
    file,
    setup: (database) => applySqlcipherKey(database, key),
  );
}

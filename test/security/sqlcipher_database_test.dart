import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/security/sqlcipher_database.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

// In the app, sqlcipher_flutter_libs registers the bundled SQLCipher build.
// Plugin binaries are unavailable under `flutter test`, so these
// integration tests load a host SQLCipher (Homebrew or $SQLCIPHER_LIB) and
// skip when none is present.
String? _findSqlcipherLibrary() {
  final candidates = [
    Platform.environment['SQLCIPHER_LIB'],
    '/opt/homebrew/opt/sqlcipher/lib/libsqlcipher.dylib',
    '/usr/local/opt/sqlcipher/lib/libsqlcipher.dylib',
    '/usr/lib/libsqlcipher.so',
  ];
  for (final candidate in candidates) {
    if (candidate != null && File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

void main() {
  group('pragma formatting', () {
    final key = Uint8List.fromList([
      ...List.generate(16, (i) => i),
      ...List.generate(16, (i) => 0xf0 + (i % 16)),
    ]);

    test('sqlcipherKeyPragma emits the raw-hex key form', () {
      final pragma = sqlcipherKeyPragma(key);

      expect(pragma, startsWith('PRAGMA key = "x\''));
      expect(pragma, endsWith('\'";'));
      expect(pragma, contains(hexEncode(key)));
      expect(hexEncode(key).length, 64);
    });

    test('sqlcipherRekeyPragma emits the raw-hex rekey form', () {
      expect(
        sqlcipherRekeyPragma(key),
        'PRAGMA rekey = "x\'${hexEncode(key)}\'";',
      );
    });

    test('hexEncode pads single-digit bytes', () {
      expect(hexEncode(Uint8List.fromList([0, 1, 255])), '0001ff');
    });
  });

  final sqlcipherPath = _findSqlcipherLibrary();

  group(
    'encrypted database',
    () {
      late Directory tempDir;
      late File dbFile;
      final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final wrongKey = Uint8List.fromList(List.generate(32, (i) => i + 2));

      setUpAll(() {
        open.overrideForAll(() => DynamicLibrary.open(sqlcipherPath!));
      });

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('sqlcipher_test');
        dbFile = File('${tempDir.path}/db.enc');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('writes an encrypted file that reopens only with the key', () {
        final db = sqlite3.open(dbFile.path);
        applySqlcipherKey(db, key);
        db
          ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY, body TEXT);')
          ..execute("INSERT INTO t (body) VALUES ('plaintext-marker');")
          ..dispose();

        // §6.1 NFR: the file on disk must not be a readable SQLite database.
        final header = dbFile.readAsBytesSync().sublist(0, 16);
        expect(String.fromCharCodes(header), isNot('SQLite format 3\x00'));

        final reopened = sqlite3.open(dbFile.path);
        applySqlcipherKey(reopened, key);
        final rows = reopened.select('SELECT body FROM t;');
        expect(rows.single['body'], 'plaintext-marker');
        reopened.dispose();

        final wrong = sqlite3.open(dbFile.path);
        applySqlcipherKey(wrong, wrongKey);
        expect(() => wrong.select('SELECT body FROM t;'), throwsA(anything));
        wrong.dispose();
      });

      test('rekey rotates the key per §6.1.5', () {
        final newKey = Uint8List.fromList(List.generate(32, (i) => 200 - i));

        final db = sqlite3.open(dbFile.path);
        applySqlcipherKey(db, key);
        db
          ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY);')
          ..execute('INSERT INTO t DEFAULT VALUES;');
        rekeySqlcipherDatabase(db, newKey);
        db.dispose();

        final reopened = sqlite3.open(dbFile.path);
        applySqlcipherKey(reopened, newKey);
        expect(reopened.select('SELECT COUNT(*) AS n FROM t;').single['n'], 1);
        reopened.dispose();

        final old = sqlite3.open(dbFile.path);
        applySqlcipherKey(old, key);
        expect(() => old.select('SELECT COUNT(*) FROM t;'), throwsA(anything));
        old.dispose();
      });

      test(
        'AppDatabase opens over openEncryptedDatabase and persists data',
        () async {
          var db = AppDatabase(openEncryptedDatabase(file: dbFile, key: key));
          await db
              .into(db.leagues)
              .insert(LeaguesCompanion.insert(id: 'league-1', name: 'MTLL'));
          await db.close();

          db = AppDatabase(openEncryptedDatabase(file: dbFile, key: key));
          final league = await (db.select(
            db.leagues,
          )..where((league) => league.id.equals('league-1'))).getSingle();
          expect(league.name, 'MTLL');
          await db.close();

          final locked = AppDatabase(
            openEncryptedDatabase(file: dbFile, key: wrongKey),
          );
          await expectLater(
            locked.select(locked.leagues).get(),
            throwsA(anything),
          );
          await locked.close();
        },
      );
    },
    skip: sqlcipherPath == null
        ? 'SQLCipher library not found (set SQLCIPHER_LIB or brew install '
              'sqlcipher)'
        : false,
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';

import '../data/database/app_database.dart';
import '../security/key_provider.dart';
import '../security/master_key_holder.dart';
import '../security/sqlcipher_database.dart';

/// One entry in the local league catalog — maps a database file stem
/// (the league UUID per EXECUTION-PLAN §6.3.1) to its display identity so
/// W1 AF-1 can detect short-name collisions without opening any database.
class LeagueCatalogEntry {
  const LeagueCatalogEntry({
    required this.stem,
    required this.name,
    this.shortName,
  });

  factory LeagueCatalogEntry.fromJson(Map<String, dynamic> json) =>
      LeagueCatalogEntry(
        stem: json['stem'] as String,
        name: json['name'] as String,
        shortName: json['shortName'] as String?,
      );

  final String stem;
  final String name;
  final String? shortName;

  Map<String, dynamic> toJson() => {
    'stem': stem,
    'name': name,
    if (shortName != null) 'shortName': shortName,
  };
}

/// Boundary between the widget tree and database construction so tests can
/// substitute an in-memory database. The production implementation owns the
/// `<app-data>/leagues/<league_uuid>/db.enc` layout (EXECUTION-PLAN §6.3.1)
/// and the §6.1 key flow.
abstract class DatabaseGateway {
  Future<List<LeagueCatalogEntry>> listLeagues();

  Future<bool> shortNameExists(String shortName);

  Future<AppDatabase> createLeagueDatabase({
    required String stem,
    required String leagueName,
    required String pin,
    String? shortName,
  });

  Future<AppDatabase> openLeagueDatabase({
    required String stem,
    required String pin,
  });
}

/// §6.1 production gateway: Argon2id-derived SQLCipher key per league file,
/// salt and KDF params in the OS keystore, master key held in memory only.
class EncryptedFileDatabaseGateway implements DatabaseGateway {
  EncryptedFileDatabaseGateway({
    required Directory appDataDirectory,
    required this._keyProvider,
    MasterKeyHolder? keyHolder,
  }) : _leaguesDirectory = Directory(
         '${appDataDirectory.path}${Platform.pathSeparator}leagues',
       ),
       _keyHolder = keyHolder ?? MasterKeyHolder();

  final Directory _leaguesDirectory;
  final KeyProvider _keyProvider;
  final MasterKeyHolder _keyHolder;

  File get _catalogFile =>
      File('${_leaguesDirectory.path}${Platform.pathSeparator}catalog.json');

  File _databaseFile(String stem) => File(
    '${_leaguesDirectory.path}${Platform.pathSeparator}$stem'
    '${Platform.pathSeparator}db.enc',
  );

  @override
  Future<List<LeagueCatalogEntry>> listLeagues() async {
    if (!_catalogFile.existsSync()) {
      return const [];
    }
    final decoded = jsonDecode(_catalogFile.readAsStringSync()) as List;
    return decoded
        .map((e) => LeagueCatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> shortNameExists(String shortName) async {
    final normalized = shortName.trim().toLowerCase();
    final entries = await listLeagues();
    return entries.any((entry) => entry.shortName?.toLowerCase() == normalized);
  }

  @override
  Future<AppDatabase> createLeagueDatabase({
    required String stem,
    required String leagueName,
    required String pin,
    String? shortName,
  }) async {
    final file = _databaseFile(stem);
    file.parent.createSync(recursive: true);

    final key = await _keyProvider.deriveKey(
      passcode: pin,
      leagueFileStem: stem,
    );
    _keyHolder.set(key);
    final db = AppDatabase(openEncryptedDatabase(file: file, key: key));

    final entries = await listLeagues();
    _catalogFile.writeAsStringSync(
      jsonEncode([
        ...entries.map((e) => e.toJson()),
        LeagueCatalogEntry(
          stem: stem,
          name: leagueName,
          shortName: shortName,
        ).toJson(),
      ]),
    );
    return db;
  }

  @override
  Future<AppDatabase> openLeagueDatabase({
    required String stem,
    required String pin,
  }) async {
    final key = await _keyProvider.deriveKey(
      passcode: pin,
      leagueFileStem: stem,
    );
    _keyHolder.set(key);
    return AppDatabase(
      openEncryptedDatabase(file: _databaseFile(stem), key: key),
    );
  }
}

/// Test/dev gateway: in-memory databases and an in-memory catalog. Keeps
/// widget tests free of keystore, Argon2id cost, and the file system.
class InMemoryDatabaseGateway implements DatabaseGateway {
  final List<LeagueCatalogEntry> _catalog = [];

  @override
  Future<List<LeagueCatalogEntry>> listLeagues() async =>
      List.unmodifiable(_catalog);

  @override
  Future<bool> shortNameExists(String shortName) async {
    final normalized = shortName.trim().toLowerCase();
    return _catalog.any(
      (entry) => entry.shortName?.toLowerCase() == normalized,
    );
  }

  @override
  Future<AppDatabase> createLeagueDatabase({
    required String stem,
    required String leagueName,
    required String pin,
    String? shortName,
  }) async {
    _catalog.add(
      LeagueCatalogEntry(stem: stem, name: leagueName, shortName: shortName),
    );
    return AppDatabase(NativeDatabase.memory());
  }

  @override
  Future<AppDatabase> openLeagueDatabase({
    required String stem,
    required String pin,
  }) async {
    return AppDatabase(NativeDatabase.memory());
  }
}

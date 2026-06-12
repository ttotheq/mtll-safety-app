import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/league_onboarding_repository.dart';
import '../data/repositories/session_context.dart';
import '../security/passcode_hasher.dart';
import 'database_gateway.dart';

/// Database construction boundary. Production overrides this in main();
/// widget tests override with [InMemoryDatabaseGateway].
final databaseGatewayProvider = Provider<DatabaseGateway>(
  (ref) => throw UnimplementedError(
    'databaseGatewayProvider must be overridden at app start',
  ),
);

/// The open database for the active league. Null until onboarding (W1) or
/// unlock completes.
final appDatabaseProvider = StateProvider<AppDatabase?>((ref) => null);

/// Authenticated session for the active league. Null before unlock.
final sessionContextProvider = StateProvider<SessionContext?>((ref) => null);

final passcodeHasherProvider = Provider<PasscodeHasher>(
  (ref) => PasscodeHasher(),
);

final leagueOnboardingRepositoryProvider = Provider<LeagueOnboardingRepository>(
  (ref) {
    final db = ref.watch(appDatabaseProvider);
    if (db == null) {
      throw StateError('No open database; onboarding/unlock must run first');
    }
    return LeagueOnboardingRepository(db: db);
  },
);

/// League catalog entries on this device; drives first-run routing.
final leagueCatalogProvider = FutureProvider<List<LeagueCatalogEntry>>(
  (ref) => ref.watch(databaseGatewayProvider).listLeagues(),
);

/// The active League row, once a database is open.
final activeLeagueProvider = FutureProvider<LeagueRow?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) {
    return null;
  }
  final rows = await db.select(db.leagues).get();
  return rows.isEmpty ? null : rows.first;
});

/// Seasons for the active league (top-bar Season selector). Empty until W2
/// (Sprint S3) creates the first season.
final seasonsProvider = FutureProvider<List<SeasonRow>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final session = ref.watch(sessionContextProvider);
  if (db == null || session == null) {
    return const [];
  }
  return (db.select(
    db.seasons,
  )..where((season) => season.leagueId.equals(session.leagueId))).get();
});

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/app/database_gateway.dart';
import 'package:mtll_safety_app/app/providers.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/repositories/league_onboarding_repository.dart';
import 'package:mtll_safety_app/data/repositories/session_context.dart';
import 'package:mtll_safety_app/presentation/shell/home_shell.dart';

Future<(AppDatabase, SessionContext)> _bootstrappedDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  final result = await LeagueOnboardingRepository(db: db).bootstrapLeague(
    leagueName: 'Mission Trails Little League',
    divisions: const [OnboardingDivisionInput(name: 'Majors', sortOrder: 10)],
    ownerEmail: 'safety@mtll.org',
    ownerName: 'Ty Quan',
    ownerPasscodeHash: 'test-hash',
  );
  return (
    db,
    SessionContext(
      leagueId: result.leagueId,
      userId: result.ownerUserId,
      role: UserRole.owner,
    ),
  );
}

Widget _shell(AppDatabase db, SessionContext session) => ProviderScope(
  overrides: [
    databaseGatewayProvider.overrideWithValue(InMemoryDatabaseGateway()),
    appDatabaseProvider.overrideWith((ref) => db),
    sessionContextProvider.overrideWith((ref) => session),
  ],
  child: const MaterialApp(home: HomeShell()),
);

void main() {
  const destinations = [
    'Dashboard',
    'Volunteers',
    'Teams',
    'Clearances',
    'Matrix',
    'Settings',
  ];

  testWidgets(
    'desktop width uses a navigation rail and reaches all primary screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final (db, session) = await _bootstrappedDb();
      addTearDown(db.close);

      await tester.pumpWidget(_shell(db, session));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // Top bar surfaces the league and the Season selector empty state.
      expect(find.text('Mission Trails Little League'), findsWidgets);
      expect(find.text('No season — set up'), findsOneWidget);

      for (final label in destinations.skip(1)) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(Scaffold),
            matching: find.text(label),
          ),
          findsWidgets,
        );
      }
    },
  );

  testWidgets(
    'mobile width uses a bottom navigation bar and reaches all screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final (db, session) = await _bootstrappedDb();
      addTearDown(db.close);

      await tester.pumpWidget(_shell(db, session));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      for (final label in destinations.skip(1)) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('dashboard shows the W1 empty-state calls-to-action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final (db, session) = await _bootstrappedDb();
    addTearDown(db.close);

    await tester.pumpWidget(_shell(db, session));
    await tester.pumpAndSettle();

    expect(find.text('Add a volunteer'), findsOneWidget);
    expect(find.text('Import from spreadsheet/CSV'), findsOneWidget);
    expect(find.text('Set up a season'), findsOneWidget);
  });
}

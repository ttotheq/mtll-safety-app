import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/repositories/league_scoped_repository.dart';
import 'package:mtll_safety_app/data/repositories/session_context.dart';
import 'package:mtll_safety_app/data/repositories/volunteer_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  const uuid = Uuid();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('VolunteerRepository tenant scoping', () {
    test('listAll only returns rows for the current league', () async {
      final leagueA = uuid.v7();
      final leagueB = uuid.v7();
      final volunteerA = uuid.v7();
      final volunteerB = uuid.v7();
      final repository = VolunteerRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA),
      );

      await _insertLeague(db, leagueA, 'League A');
      await _insertLeague(db, leagueB, 'League B');
      await _insertVolunteer(
        db,
        leagueId: leagueA,
        volunteerId: volunteerA,
        firstName: 'Alex',
      );
      await _insertVolunteer(
        db,
        leagueId: leagueB,
        volunteerId: volunteerB,
        firstName: 'Bailey',
      );

      final volunteers = await repository.listAll();

      expect(volunteers.map((volunteer) => volunteer.id), [volunteerA]);
      expect(volunteers.single.leagueId, leagueA);
    });

    test('getById returns a row owned by the current league', () async {
      final leagueA = uuid.v7();
      final volunteerA = uuid.v7();
      final repository = VolunteerRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA),
      );

      await _insertLeague(db, leagueA, 'League A');
      await _insertVolunteer(
        db,
        leagueId: leagueA,
        volunteerId: volunteerA,
        firstName: 'Alex',
      );

      final volunteer = await repository.getById(volunteerA);

      expect(volunteer, isNotNull);
      expect(volunteer!.id, volunteerA);
      expect(volunteer.leagueId, leagueA);
    });

    test(
      'getById audits and throws on a cross-tenant volunteer lookup',
      () async {
        final leagueA = uuid.v7();
        final leagueB = uuid.v7();
        final userA = uuid.v7();
        final volunteerB = uuid.v7();
        final repository = VolunteerRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueA, userId: userA),
        );

        await _insertLeague(db, leagueA, 'League A');
        await _insertLeague(db, leagueB, 'League B');
        await _insertVolunteer(
          db,
          leagueId: leagueB,
          volunteerId: volunteerB,
          firstName: 'Bailey',
        );

        await expectLater(
          repository.getById(volunteerB),
          throwsA(isA<AssertionError>()),
        );

        final auditRows = await (db.select(
          db.auditLogs,
        )..where((audit) => audit.entityId.equals(volunteerB))).get();

        expect(auditRows, hasLength(1));
        expect(
          auditRows.single.action,
          LeagueScopedRepository.crossTenantAccessAttemptAction,
        );
        expect(auditRows.single.leagueId, leagueA);
        expect(auditRows.single.userId, userA);
        expect(jsonDecode(auditRows.single.afterJson!), {
          'sessionLeagueId': leagueA,
          'rowLeagueId': leagueB,
        });
      },
    );
  });
}

Future<void> _insertLeague(AppDatabase db, String id, String name) {
  return db
      .into(db.leagues)
      .insert(LeaguesCompanion.insert(id: id, name: name));
}

Future<void> _insertVolunteer(
  AppDatabase db, {
  required String leagueId,
  required String volunteerId,
  required String firstName,
}) {
  return db
      .into(db.volunteers)
      .insert(
        VolunteersCompanion.insert(
          id: volunteerId,
          leagueId: leagueId,
          firstName: firstName,
          lastName: 'Volunteer',
        ),
      );
}

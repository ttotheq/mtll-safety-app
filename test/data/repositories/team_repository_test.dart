import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/repositories/league_scoped_repository.dart';
import 'package:mtll_safety_app/data/repositories/session_context.dart';
import 'package:mtll_safety_app/data/repositories/team_repository.dart';
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

  group('TeamRepository', () {
    test(
      'listAll only returns rows for the current league in display order',
      () async {
        final leagueA = uuid.v7();
        final leagueB = uuid.v7();
        final seasonA = uuid.v7();
        final divisionA = uuid.v7();
        final repository = TeamRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueA),
        );

        await _insertLeague(db, leagueA, 'League A');
        await _insertLeague(db, leagueB, 'League B');
        await _insertTeam(
          db,
          id: uuid.v7(),
          leagueId: leagueA,
          seasonId: seasonA,
          divisionId: divisionA,
          name: 'RAMIREZ',
          displayName: 'MAJORS - RAMIREZ',
        );
        await _insertTeam(
          db,
          id: uuid.v7(),
          leagueId: leagueA,
          seasonId: seasonA,
          divisionId: divisionA,
          name: 'BONILLA',
          displayName: 'MAJORS - BONILLA',
        );
        await _insertTeam(
          db,
          id: uuid.v7(),
          leagueId: leagueB,
          seasonId: uuid.v7(),
          divisionId: uuid.v7(),
          name: 'OTHER',
          displayName: 'JUNIORS - OTHER',
        );

        final rows = await repository.listAll();

        expect(rows.map((row) => row.displayName), [
          'MAJORS - BONILLA',
          'MAJORS - RAMIREZ',
        ]);
        expect(rows.every((row) => row.leagueId == leagueA), isTrue);
      },
    );

    test('getById audits and throws on a cross-tenant lookup', () async {
      final leagueA = uuid.v7();
      final leagueB = uuid.v7();
      final userA = uuid.v7();
      final teamB = uuid.v7();
      final repository = TeamRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA, userId: userA),
      );

      await _insertLeague(db, leagueA, 'League A');
      await _insertLeague(db, leagueB, 'League B');
      await _insertTeam(
        db,
        id: teamB,
        leagueId: leagueB,
        seasonId: uuid.v7(),
        divisionId: uuid.v7(),
        name: 'BONILLA',
        displayName: 'MAJORS - BONILLA',
      );

      await expectLater(
        repository.getById(teamB),
        throwsA(isA<AssertionError>()),
      );

      final auditRows = await (db.select(
        db.auditLogs,
      )..where((audit) => audit.entityId.equals(teamB))).get();

      expect(auditRows, hasLength(1));
      expect(
        auditRows.single.action,
        LeagueScopedRepository.crossTenantAccessAttemptAction,
      );
      expect(jsonDecode(auditRows.single.afterJson!), {
        'sessionLeagueId': leagueA,
        'rowLeagueId': leagueB,
      });
    });

    test(
      'create and update compute display_name and audit changes',
      () async {
        final leagueId = uuid.v7();
        final userId = uuid.v7();
        final seasonId = uuid.v7();
        final majors = uuid.v7();
        final minors = uuid.v7();
        final repository = TeamRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueId, userId: userId),
        );

        await _insertLeague(db, leagueId, 'League A');
        await _insertDivision(
          db,
          id: majors,
          leagueId: leagueId,
          name: 'Majors',
          sortOrder: 10,
        );
        await _insertDivision(
          db,
          id: minors,
          leagueId: leagueId,
          name: 'Tee Ball',
          sortOrder: 20,
        );

        final created = await repository.create(
          seasonId: seasonId,
          divisionId: majors,
          name: ' Bonilla ',
        );
        final updated = await repository.update(
          id: created.id,
          divisionId: minors,
          name: 'Ramirez',
          color: 'blue',
        );

        expect(created.leagueId, leagueId);
        expect(created.createdByUserId, userId);
        expect(created.name, 'Bonilla');
        expect(created.displayName, 'MAJORS - BONILLA');
        expect(updated, isNotNull);
        expect(updated!.divisionId, minors);
        expect(updated.name, 'Ramirez');
        expect(updated.displayName, 'TEE BALL - RAMIREZ');
        expect(updated.color, 'blue');
        expect(updated.updatedByUserId, userId);

        final auditRows = await (db.select(
          db.auditLogs,
        )..where((audit) => audit.entityId.equals(created.id))).get();

        expect(auditRows.map((row) => row.action), [
          LeagueScopedRepository.createAction,
          LeagueScopedRepository.updateAction,
        ]);
        expect(auditRows.first.beforeJson, isNull);
        expect(
          jsonDecode(auditRows.first.afterJson!)['displayName'],
          'MAJORS - BONILLA',
        );
        expect(
          jsonDecode(auditRows.last.afterJson!)['displayName'],
          'TEE BALL - RAMIREZ',
        );
      },
    );

    test('create audits and throws on a cross-tenant division', () async {
      final leagueA = uuid.v7();
      final leagueB = uuid.v7();
      final divisionB = uuid.v7();
      final repository = TeamRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA),
      );

      await _insertLeague(db, leagueA, 'League A');
      await _insertLeague(db, leagueB, 'League B');
      await _insertDivision(
        db,
        id: divisionB,
        leagueId: leagueB,
        name: 'Majors',
        sortOrder: 10,
      );

      await expectLater(
        repository.create(
          seasonId: uuid.v7(),
          divisionId: divisionB,
          name: 'Bonilla',
        ),
        throwsA(isA<AssertionError>()),
      );

      final auditRows = await (db.select(
        db.auditLogs,
      )..where((audit) => audit.entityId.equals(divisionB))).get();

      expect(auditRows, hasLength(1));
      expect(
        auditRows.single.action,
        LeagueScopedRepository.crossTenantAccessAttemptAction,
      );
    });
  });
}

Future<void> _insertLeague(AppDatabase db, String id, String name) {
  return db
      .into(db.leagues)
      .insert(LeaguesCompanion.insert(id: id, name: name));
}

Future<void> _insertDivision(
  AppDatabase db, {
  required String id,
  required String leagueId,
  required String name,
  required int sortOrder,
}) {
  return db
      .into(db.divisions)
      .insert(
        DivisionsCompanion.insert(
          id: id,
          leagueId: leagueId,
          name: name,
          sortOrder: sortOrder,
        ),
      );
}

Future<void> _insertTeam(
  AppDatabase db, {
  required String id,
  required String leagueId,
  required String seasonId,
  required String divisionId,
  required String name,
  required String displayName,
}) {
  return db
      .into(db.teams)
      .insert(
        TeamsCompanion.insert(
          id: id,
          leagueId: leagueId,
          seasonId: seasonId,
          divisionId: divisionId,
          name: name,
          displayName: displayName,
        ),
      );
}

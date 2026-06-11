import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/repositories/league_scoped_repository.dart';
import 'package:mtll_safety_app/data/repositories/session_context.dart';
import 'package:mtll_safety_app/data/repositories/volunteer_assignment_repository.dart';
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

  group('VolunteerAssignmentRepository', () {
    test(
      'listAll only returns rows for the current league in start order',
      () async {
        final leagueA = uuid.v7();
        final leagueB = uuid.v7();
        final volunteerA = uuid.v7();
        final repository = VolunteerAssignmentRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueA),
        );

        await _insertLeague(db, leagueA, 'League A');
        await _insertLeague(db, leagueB, 'League B');
        final laterId = uuid.v7();
        final earlierId = uuid.v7();
        await _insertAssignment(
          db,
          id: laterId,
          leagueId: leagueA,
          volunteerId: volunteerA,
          startedAt: DateTime.utc(2026, 3, 1),
        );
        await _insertAssignment(
          db,
          id: earlierId,
          leagueId: leagueA,
          volunteerId: volunteerA,
          startedAt: DateTime.utc(2026, 2, 1),
        );
        await _insertAssignment(
          db,
          id: uuid.v7(),
          leagueId: leagueB,
          volunteerId: uuid.v7(),
          startedAt: DateTime.utc(2026, 1, 1),
        );

        final rows = await repository.listAll();

        expect(rows.map((row) => row.id), [earlierId, laterId]);
        expect(rows.every((row) => row.leagueId == leagueA), isTrue);
      },
    );

    test('getById audits and throws on a cross-tenant lookup', () async {
      final leagueA = uuid.v7();
      final leagueB = uuid.v7();
      final userA = uuid.v7();
      final assignmentB = uuid.v7();
      final repository = VolunteerAssignmentRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA, userId: userA),
      );

      await _insertLeague(db, leagueA, 'League A');
      await _insertLeague(db, leagueB, 'League B');
      await _insertAssignment(
        db,
        id: assignmentB,
        leagueId: leagueB,
        volunteerId: uuid.v7(),
        startedAt: DateTime.utc(2026, 2, 1),
      );

      await expectLater(
        repository.getById(assignmentB),
        throwsA(isA<AssertionError>()),
      );

      final auditRows = await (db.select(
        db.auditLogs,
      )..where((audit) => audit.entityId.equals(assignmentB))).get();

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
      'create and update persist tenant metadata and audit changes',
      () async {
        final leagueId = uuid.v7();
        final userId = uuid.v7();
        final volunteerId = uuid.v7();
        final seasonId = uuid.v7();
        final roleId = uuid.v7();
        final teamId = uuid.v7();
        final repository = VolunteerAssignmentRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueId, userId: userId),
        );

        await _insertLeague(db, leagueId, 'League A');

        final created = await repository.create(
          volunteerId: volunteerId,
          seasonId: seasonId,
          roleId: roleId,
          teamId: teamId,
          startedAt: DateTime.utc(2026, 2, 1),
        );
        final endedAt = DateTime.utc(2026, 5, 1);
        final updated = await repository.update(
          id: created.id,
          status: VolunteerAssignmentStatuses.removed,
          teamId: teamId,
          endedAt: endedAt,
        );

        expect(created.leagueId, leagueId);
        expect(created.createdByUserId, userId);
        expect(created.status, VolunteerAssignmentStatuses.active);
        expect(created.endedAt, isNull);
        expect(updated, isNotNull);
        expect(updated!.status, VolunteerAssignmentStatuses.removed);
        expect(updated.endedAt!.toUtc(), endedAt);
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
          jsonDecode(auditRows.first.afterJson!)['status'],
          VolunteerAssignmentStatuses.active,
        );
        expect(
          jsonDecode(auditRows.last.beforeJson!)['status'],
          VolunteerAssignmentStatuses.active,
        );
        expect(
          jsonDecode(auditRows.last.afterJson!)['status'],
          VolunteerAssignmentStatuses.removed,
        );
      },
    );

    test('create rejects an unknown status', () async {
      final leagueId = uuid.v7();
      final repository = VolunteerAssignmentRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueId),
      );

      await _insertLeague(db, leagueId, 'League A');

      await expectLater(
        repository.create(
          volunteerId: uuid.v7(),
          seasonId: uuid.v7(),
          roleId: uuid.v7(),
          startedAt: DateTime.utc(2026, 2, 1),
          status: 'BENCHED',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

Future<void> _insertLeague(AppDatabase db, String id, String name) {
  return db
      .into(db.leagues)
      .insert(LeaguesCompanion.insert(id: id, name: name));
}

Future<void> _insertAssignment(
  AppDatabase db, {
  required String id,
  required String leagueId,
  required String volunteerId,
  required DateTime startedAt,
}) {
  return db
      .into(db.volunteerAssignments)
      .insert(
        VolunteerAssignmentsCompanion.insert(
          id: id,
          leagueId: leagueId,
          volunteerId: volunteerId,
          seasonId: const Uuid().v7(),
          roleId: const Uuid().v7(),
          startedAt: startedAt,
          status: VolunteerAssignmentStatuses.active,
        ),
      );
}

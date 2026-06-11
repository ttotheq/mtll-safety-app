import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/repositories/league_scoped_repository.dart';
import 'package:mtll_safety_app/data/repositories/role_clearance_requirement_repository.dart';
import 'package:mtll_safety_app/data/repositories/session_context.dart';
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

  group('RoleClearanceRequirementRepository', () {
    test('listAll only returns rows for the current league', () async {
      final leagueA = uuid.v7();
      final leagueB = uuid.v7();
      final roleA = uuid.v7();
      final roleB = uuid.v7();
      final clearanceType = uuid.v7();
      final repository = RoleClearanceRequirementRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA),
      );

      await _insertLeague(db, leagueA, 'League A');
      await _insertLeague(db, leagueB, 'League B');
      await _insertRequirement(
        db,
        id: uuid.v7(),
        leagueId: leagueA,
        roleId: roleA,
        clearanceTypeId: clearanceType,
        requirement: 'REQUIRED',
      );
      await _insertRequirement(
        db,
        id: uuid.v7(),
        leagueId: leagueB,
        roleId: roleB,
        clearanceTypeId: clearanceType,
        requirement: 'OPTIONAL',
      );

      final rows = await repository.listAll();

      expect(rows, hasLength(1));
      expect(rows.single.leagueId, leagueA);
      expect(rows.single.requirement, 'REQUIRED');
    });

    test('getById audits and throws on a cross-tenant lookup', () async {
      final leagueA = uuid.v7();
      final leagueB = uuid.v7();
      final userA = uuid.v7();
      final requirementB = uuid.v7();
      final repository = RoleClearanceRequirementRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA, userId: userA),
      );

      await _insertLeague(db, leagueA, 'League A');
      await _insertLeague(db, leagueB, 'League B');
      await _insertRequirement(
        db,
        id: requirementB,
        leagueId: leagueB,
        roleId: uuid.v7(),
        clearanceTypeId: uuid.v7(),
        requirement: 'REQUIRED',
      );

      await expectLater(
        repository.getById(requirementB),
        throwsA(isA<AssertionError>()),
      );

      final auditRows = await (db.select(
        db.auditLogs,
      )..where((audit) => audit.entityId.equals(requirementB))).get();

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
        final roleId = uuid.v7();
        final clearanceTypeId = uuid.v7();
        final repository = RoleClearanceRequirementRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueId, userId: userId),
        );

        await _insertLeague(db, leagueId, 'League A');

        final created = await repository.create(
          roleId: roleId,
          clearanceTypeId: clearanceTypeId,
          requirement: 'REQUIRED',
          minAge: 18,
        );
        final updated = await repository.update(
          id: created.id,
          requirement: 'CONDITIONAL_OK',
          notes: 'matrix override',
        );

        expect(created.leagueId, leagueId);
        expect(created.createdByUserId, userId);
        expect(created.requirement, 'REQUIRED');
        expect(created.minAge, 18);
        expect(updated, isNotNull);
        expect(updated!.requirement, 'CONDITIONAL_OK');
        expect(updated.minAge, isNull);
        expect(updated.notes, 'matrix override');
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
          jsonDecode(auditRows.first.afterJson!)['requirement'],
          'REQUIRED',
        );
        expect(
          jsonDecode(auditRows.last.beforeJson!)['requirement'],
          'REQUIRED',
        );
        expect(
          jsonDecode(auditRows.last.afterJson!)['requirement'],
          'CONDITIONAL_OK',
        );
      },
    );

    test('create rejects an unknown requirement level', () async {
      final leagueId = uuid.v7();
      final repository = RoleClearanceRequirementRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueId),
      );

      await _insertLeague(db, leagueId, 'League A');

      await expectLater(
        repository.create(
          roleId: uuid.v7(),
          clearanceTypeId: uuid.v7(),
          requirement: 'SOMETIMES',
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

Future<void> _insertRequirement(
  AppDatabase db, {
  required String id,
  required String leagueId,
  required String roleId,
  required String clearanceTypeId,
  required String requirement,
}) {
  return db
      .into(db.roleClearanceRequirements)
      .insert(
        RoleClearanceRequirementsCompanion.insert(
          id: id,
          leagueId: leagueId,
          seasonId: const Value(null),
          roleId: roleId,
          clearanceTypeId: clearanceTypeId,
          requirement: requirement,
        ),
      );
}

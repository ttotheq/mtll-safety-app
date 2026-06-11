import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/repositories/division_repository.dart';
import 'package:mtll_safety_app/data/repositories/league_scoped_repository.dart';
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

  group('DivisionRepository', () {
    test(
      'listAll only returns rows for the current league in sort order',
      () async {
        final leagueA = uuid.v7();
        final leagueB = uuid.v7();
        final repository = DivisionRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueA),
        );

        await _insertLeague(db, leagueA, 'League A');
        await _insertLeague(db, leagueB, 'League B');
        await _insertDivision(
          db,
          id: uuid.v7(),
          leagueId: leagueA,
          name: 'Majors',
          sortOrder: 20,
        );
        await _insertDivision(
          db,
          id: uuid.v7(),
          leagueId: leagueA,
          name: 'Tee Ball',
          sortOrder: 10,
        );
        await _insertDivision(
          db,
          id: uuid.v7(),
          leagueId: leagueB,
          name: 'Juniors',
          sortOrder: 5,
        );

        final rows = await repository.listAll();

        expect(rows.map((row) => row.name), ['Tee Ball', 'Majors']);
        expect(rows.every((row) => row.leagueId == leagueA), isTrue);
      },
    );

    test('getById audits and throws on a cross-tenant lookup', () async {
      final leagueA = uuid.v7();
      final leagueB = uuid.v7();
      final userA = uuid.v7();
      final divisionB = uuid.v7();
      final repository = DivisionRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA, userId: userA),
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
        repository.getById(divisionB),
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
        final repository = DivisionRepository(
          db: db,
          sessionContext: SessionContext(
            leagueId: leagueId,
            userId: userId,
            role: UserRole.admin,
          ),
        );

        await _insertLeague(db, leagueId, 'League A');

        final created = await repository.create(
          name: ' Majors ',
          sortOrder: 10,
          ageMin: 9,
          ageMax: 10,
        );
        final updated = await repository.update(
          id: created.id,
          name: 'Majors AA',
          sortOrder: 30,
          ageMin: 10,
          ageMax: 11,
        );

        expect(created.leagueId, leagueId);
        expect(created.createdByUserId, userId);
        expect(created.name, 'Majors');
        expect(updated, isNotNull);
        expect(updated!.name, 'Majors AA');
        expect(updated.sortOrder, 30);
        expect(updated.ageMin, 10);
        expect(updated.ageMax, 11);
        expect(updated.updatedByUserId, userId);

        final auditRows = await (db.select(
          db.auditLogs,
        )..where((audit) => audit.entityId.equals(created.id))).get();

        expect(auditRows.map((row) => row.action), [
          LeagueScopedRepository.createAction,
          LeagueScopedRepository.updateAction,
        ]);
        expect(auditRows.first.beforeJson, isNull);
        expect(jsonDecode(auditRows.first.afterJson!)['name'], 'Majors');
        expect(jsonDecode(auditRows.last.beforeJson!)['name'], 'Majors');
        expect(jsonDecode(auditRows.last.afterJson!)['name'], 'Majors AA');
      },
    );
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

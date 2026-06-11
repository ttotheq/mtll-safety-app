import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/repositories/league_scoped_repository.dart';
import 'package:mtll_safety_app/data/repositories/role_repository.dart';
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

  group('RoleRepository', () {
    test(
      'listAll only returns rows for the current league in sort order',
      () async {
        final leagueA = uuid.v7();
        final leagueB = uuid.v7();
        final repository = RoleRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueA),
        );

        await _insertLeague(db, leagueA, 'League A');
        await _insertLeague(db, leagueB, 'League B');
        await _insertRole(
          db,
          id: uuid.v7(),
          leagueId: leagueA,
          name: 'Umpire',
          sortOrder: 20,
        );
        await _insertRole(
          db,
          id: uuid.v7(),
          leagueId: leagueA,
          name: 'Manager',
          sortOrder: 10,
          isOnField: true,
        );
        await _insertRole(
          db,
          id: uuid.v7(),
          leagueId: leagueB,
          name: 'Scorekeeper',
          sortOrder: 5,
        );

        final rows = await repository.listAll();

        expect(rows.map((row) => row.name), ['Manager', 'Umpire']);
        expect(rows.every((row) => row.leagueId == leagueA), isTrue);
      },
    );

    test('getById audits and throws on a cross-tenant lookup', () async {
      final leagueA = uuid.v7();
      final leagueB = uuid.v7();
      final userA = uuid.v7();
      final roleB = uuid.v7();
      final repository = RoleRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA, userId: userA),
      );

      await _insertLeague(db, leagueA, 'League A');
      await _insertLeague(db, leagueB, 'League B');
      await _insertRole(
        db,
        id: roleB,
        leagueId: leagueB,
        name: 'Manager',
        sortOrder: 10,
        isOnField: true,
      );

      await expectLater(
        repository.getById(roleB),
        throwsA(isA<AssertionError>()),
      );

      final auditRows = await (db.select(
        db.auditLogs,
      )..where((audit) => audit.entityId.equals(roleB))).get();

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
        final repository = RoleRepository(
          db: db,
          sessionContext: SessionContext(
            leagueId: leagueId,
            userId: userId,
            role: UserRole.admin,
          ),
        );

        await _insertLeague(db, leagueId, 'League A');

        final created = await repository.create(
          name: ' Team Parent ',
          isOnField: false,
          permitsMinor: false,
          sortOrder: 40,
        );
        final updated = await repository.update(
          id: created.id,
          name: 'Assistant Coach (Dugout)',
          isOnField: false,
          permitsMinor: false,
          sortOrder: 35,
        );

        expect(created.leagueId, leagueId);
        expect(created.createdByUserId, userId);
        expect(created.name, 'Team Parent');
        expect(updated, isNotNull);
        expect(updated!.name, 'Assistant Coach (Dugout)');
        expect(updated.sortOrder, 35);
        expect(updated.updatedByUserId, userId);

        final auditRows = await (db.select(
          db.auditLogs,
        )..where((audit) => audit.entityId.equals(created.id))).get();

        expect(auditRows.map((row) => row.action), [
          LeagueScopedRepository.createAction,
          LeagueScopedRepository.updateAction,
        ]);
        expect(jsonDecode(auditRows.first.afterJson!)['name'], 'Team Parent');
        expect(jsonDecode(auditRows.last.beforeJson!)['name'], 'Team Parent');
        expect(
          jsonDecode(auditRows.last.afterJson!)['name'],
          'Assistant Coach (Dugout)',
        );
      },
    );
  });
}

Future<void> _insertLeague(AppDatabase db, String id, String name) {
  return db
      .into(db.leagues)
      .insert(LeaguesCompanion.insert(id: id, name: name));
}

Future<void> _insertRole(
  AppDatabase db, {
  required String id,
  required String leagueId,
  required String name,
  required int sortOrder,
  bool isOnField = false,
  bool permitsMinor = false,
}) {
  return db
      .into(db.roles)
      .insert(
        RolesCompanion.insert(
          id: id,
          leagueId: leagueId,
          name: name,
          isOnField: isOnField,
          permitsMinor: permitsMinor,
          sortOrder: sortOrder,
        ),
      );
}

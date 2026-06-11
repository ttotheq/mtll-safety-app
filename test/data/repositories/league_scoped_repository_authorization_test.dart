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

  group('UserRole', () {
    test('hierarchy is VIEWER < ADMIN < OWNER', () {
      expect(UserRole.viewer.atLeast(UserRole.viewer), isTrue);
      expect(UserRole.viewer.atLeast(UserRole.admin), isFalse);
      expect(UserRole.viewer.atLeast(UserRole.owner), isFalse);
      expect(UserRole.admin.atLeast(UserRole.viewer), isTrue);
      expect(UserRole.admin.atLeast(UserRole.admin), isTrue);
      expect(UserRole.admin.atLeast(UserRole.owner), isFalse);
      expect(UserRole.owner.atLeast(UserRole.admin), isTrue);
      expect(UserRole.owner.atLeast(UserRole.owner), isTrue);
    });
  });

  group('repository authorization', () {
    test('viewer create is denied, audited, and writes no row', () async {
      final leagueId = uuid.v7();
      final userId = uuid.v7();
      final repository = DivisionRepository(
        db: db,
        sessionContext: SessionContext(
          leagueId: leagueId,
          userId: userId,
          role: UserRole.viewer,
        ),
      );

      await _insertLeague(db, leagueId, 'League A');

      await expectLater(
        repository.create(name: 'Majors', sortOrder: 10),
        throwsA(isA<AuthorizationException>()),
      );

      final divisions = await db.select(db.divisions).get();
      expect(divisions, isEmpty);

      final auditRows =
          await (db.select(db.auditLogs)..where(
                (audit) => audit.action.equals(
                  LeagueScopedRepository.authorizationDeniedAction,
                ),
              ))
              .get();

      expect(auditRows, hasLength(1));
      expect(auditRows.single.entity, 'Division');
      expect(auditRows.single.leagueId, leagueId);
      expect(auditRows.single.userId, userId);
      expect(jsonDecode(auditRows.single.afterJson!), {
        'operation': 'create',
        'requiredRole': 'ADMIN',
        'sessionRole': 'VIEWER',
      });
    });

    test('viewer update is denied and audited with the target id', () async {
      final leagueId = uuid.v7();
      final divisionId = uuid.v7();
      final repository = DivisionRepository(
        db: db,
        sessionContext: SessionContext(
          leagueId: leagueId,
          role: UserRole.viewer,
        ),
      );

      await _insertLeague(db, leagueId, 'League A');
      await db
          .into(db.divisions)
          .insert(
            DivisionsCompanion.insert(
              id: divisionId,
              leagueId: leagueId,
              name: 'Majors',
              sortOrder: 10,
            ),
          );

      await expectLater(
        repository.update(id: divisionId, name: 'Majors AA', sortOrder: 20),
        throwsA(isA<AuthorizationException>()),
      );

      final auditRows = await (db.select(
        db.auditLogs,
      )..where((audit) => audit.entityId.equals(divisionId))).get();

      expect(auditRows, hasLength(1));
      expect(
        auditRows.single.action,
        LeagueScopedRepository.authorizationDeniedAction,
      );

      final unchanged = await (db.select(
        db.divisions,
      )..where((division) => division.id.equals(divisionId))).getSingle();
      expect(unchanged.name, 'Majors');
    });

    test('viewer reads are still permitted', () async {
      final leagueId = uuid.v7();
      final repository = DivisionRepository(
        db: db,
        sessionContext: SessionContext(
          leagueId: leagueId,
          role: UserRole.viewer,
        ),
      );

      await _insertLeague(db, leagueId, 'League A');

      expect(await repository.listAll(), isEmpty);
    });

    test('owner passes an admin-minimum gate', () async {
      final leagueId = uuid.v7();
      final repository = DivisionRepository(
        db: db,
        sessionContext: SessionContext(
          leagueId: leagueId,
          role: UserRole.owner,
        ),
      );

      await _insertLeague(db, leagueId, 'League A');

      final created = await repository.create(name: 'Majors', sortOrder: 10);

      expect(created.name, 'Majors');
    });
  });
}

Future<void> _insertLeague(AppDatabase db, String id, String name) {
  return db
      .into(db.leagues)
      .insert(LeaguesCompanion.insert(id: id, name: name));
}

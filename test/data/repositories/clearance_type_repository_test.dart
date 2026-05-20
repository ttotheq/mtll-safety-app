import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/repositories/clearance_type_repository.dart';
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

  group('ClearanceTypeRepository', () {
    test(
      'listAll only returns rows for the current league in sort order',
      () async {
        final leagueA = uuid.v7();
        final leagueB = uuid.v7();
        final repository = ClearanceTypeRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueA),
        );

        await _insertLeague(db, leagueA, 'League A');
        await _insertLeague(db, leagueB, 'League B');
        await _insertClearanceType(
          db,
          id: uuid.v7(),
          leagueId: leagueA,
          code: 'SAFETY_TRAINING',
          sortOrder: 20,
        );
        await _insertClearanceType(
          db,
          id: uuid.v7(),
          leagueId: leagueA,
          code: 'BACKGROUND_CHECK',
          sortOrder: 10,
        );
        await _insertClearanceType(
          db,
          id: uuid.v7(),
          leagueId: leagueB,
          code: 'LIVESCAN',
          sortOrder: 5,
        );

        final rows = await repository.listAll();

        expect(rows.map((row) => row.code), [
          'BACKGROUND_CHECK',
          'SAFETY_TRAINING',
        ]);
        expect(rows.every((row) => row.leagueId == leagueA), isTrue);
      },
    );

    test('getById audits and throws on a cross-tenant lookup', () async {
      final leagueA = uuid.v7();
      final leagueB = uuid.v7();
      final userA = uuid.v7();
      final clearanceTypeB = uuid.v7();
      final repository = ClearanceTypeRepository(
        db: db,
        sessionContext: SessionContext(leagueId: leagueA, userId: userA),
      );

      await _insertLeague(db, leagueA, 'League A');
      await _insertLeague(db, leagueB, 'League B');
      await _insertClearanceType(
        db,
        id: clearanceTypeB,
        leagueId: leagueB,
        code: 'BACKGROUND_CHECK',
        sortOrder: 10,
      );

      await expectLater(
        repository.getById(clearanceTypeB),
        throwsA(isA<AssertionError>()),
      );

      final auditRows = await (db.select(
        db.auditLogs,
      )..where((audit) => audit.entityId.equals(clearanceTypeB))).get();

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
        final repository = ClearanceTypeRepository(
          db: db,
          sessionContext: SessionContext(leagueId: leagueId, userId: userId),
        );

        await _insertLeague(db, leagueId, 'League A');

        final created = await repository.create(
          code: ' FIRST_AID ',
          name: ' First Aid ',
          category: ' NEW_SEASON ',
          isRecurring: true,
          evidenceRequired: true,
          sortOrder: 40,
          evidenceFormatHint: ' pdf ',
          description: ' basic coverage ',
        );
        final updated = await repository.update(
          id: created.id,
          code: 'FIRST_AID',
          name: 'First Aid / CPR',
          category: 'NEW_SEASON',
          isRecurring: true,
          evidenceRequired: false,
          sortOrder: 45,
          defaultValidityMonths: 12,
          evidenceFormatHint: 'pdf, jpg',
          description: 'Updated requirement',
          sourceUrl: ' https://example.com/first-aid ',
          active: false,
        );

        expect(created.leagueId, leagueId);
        expect(created.createdByUserId, userId);
        expect(created.code, 'FIRST_AID');
        expect(created.name, 'First Aid');
        expect(created.category, 'NEW_SEASON');
        expect(created.evidenceFormatHint, 'pdf');
        expect(updated, isNotNull);
        expect(updated!.name, 'First Aid / CPR');
        expect(updated.evidenceRequired, isFalse);
        expect(updated.defaultValidityMonths, 12);
        expect(updated.sourceUrl, 'https://example.com/first-aid');
        expect(updated.active, isFalse);

        final auditRows = await (db.select(
          db.auditLogs,
        )..where((audit) => audit.entityId.equals(created.id))).get();

        expect(auditRows.map((row) => row.action), [
          LeagueScopedRepository.createAction,
          LeagueScopedRepository.updateAction,
        ]);
        expect(jsonDecode(auditRows.first.afterJson!)['code'], 'FIRST_AID');
        expect(jsonDecode(auditRows.last.beforeJson!)['name'], 'First Aid');
        expect(
          jsonDecode(auditRows.last.afterJson!)['name'],
          'First Aid / CPR',
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

Future<void> _insertClearanceType(
  AppDatabase db, {
  required String id,
  required String leagueId,
  required String code,
  required int sortOrder,
}) {
  return db
      .into(db.clearanceTypes)
      .insert(
        ClearanceTypesCompanion.insert(
          id: id,
          leagueId: leagueId,
          code: code,
          name: code,
          category: 'ANNUAL',
          isRecurring: true,
          evidenceRequired: true,
          sortOrder: sortOrder,
        ),
      );
}

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/database/seeds/clearance_seed_data.dart';
import 'package:mtll_safety_app/data/database/seeds/division_seed_data.dart';
import 'package:mtll_safety_app/data/database/seeds/role_seed_data.dart';
import 'package:mtll_safety_app/data/repositories/league_onboarding_repository.dart';

void main() {
  late AppDatabase db;
  late LeagueOnboardingRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = LeagueOnboardingRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LeagueOnboardingRepository.bootstrapLeague', () {
    test('seeds the league defaults, owner, and audit trail', () async {
      final selectedDivisions = [
        OnboardingDivisionInput(
          name: defaultDivisionSeeds[4].name,
          sortOrder: defaultDivisionSeeds[4].sortOrder,
        ),
        OnboardingDivisionInput(
          name: defaultDivisionSeeds[0].name,
          sortOrder: defaultDivisionSeeds[0].sortOrder,
        ),
        const OnboardingDivisionInput(
          name: 'Custom Division',
          sortOrder: 999,
          ageMin: 17,
          ageMax: 18,
        ),
      ];

      final result = await repository.bootstrapLeague(
        leagueName: 'Mission Trails Little League',
        divisions: selectedDivisions,
        ownerEmail: 'owner@example.com',
        ownerName: 'League Owner',
        ownerPasscodeHash: 'hashed-pin',
        shortName: 'MTLL',
      );

      final leagues = await db.select(db.leagues).get();
      final divisions =
          await (db.select(db.divisions)..orderBy([
                (division) => OrderingTerm(expression: division.sortOrder),
              ]))
              .get();
      final roles = await (db.select(
        db.roles,
      )..orderBy([(role) => OrderingTerm(expression: role.sortOrder)])).get();
      final clearanceTypes =
          await (db.select(db.clearanceTypes)..orderBy([
                (clearanceType) =>
                    OrderingTerm(expression: clearanceType.sortOrder),
              ]))
              .get();
      final requirements = await db.select(db.roleClearanceRequirements).get();
      final users = await db.select(db.users).get();
      final auditLogs = await db.select(db.auditLogs).get();

      expect(result.divisionCount, selectedDivisions.length);
      expect(result.roleCount, defaultRoleSeeds.length);
      expect(result.clearanceTypeCount, defaultClearanceTypeSeeds.length);
      expect(
        result.requirementCount,
        defaultRoleClearanceRequirementSeeds.length,
      );

      expect(leagues, hasLength(1));
      expect(leagues.single.id, result.leagueId);
      expect(leagues.single.name, 'Mission Trails Little League');
      expect(leagues.single.shortName, 'MTLL');
      expect(leagues.single.createdByUserId, result.ownerUserId);

      expect(divisions.map((division) => division.name), [
        'Tee Ball',
        'Majors',
        'Custom Division',
      ]);
      expect(
        divisions.every((division) => division.leagueId == result.leagueId),
        isTrue,
      );
      expect(divisions.last.ageMin, 17);
      expect(divisions.last.ageMax, 18);

      expect(roles.map((role) => role.name), [
        for (final seed in defaultRoleSeeds) seed.name,
      ]);
      expect(roles.where((role) => role.name == 'Junior Scorekeeper'), isEmpty);
      expect(
        roles
            .singleWhere((role) => role.name == SeedRoleNames.juniorUmpire)
            .permitsMinor,
        isTrue,
      );
      expect(
        roles
            .singleWhere((role) => role.name == SeedRoleNames.notAssigned)
            .isOnField,
        isFalse,
      );

      expect(clearanceTypes, hasLength(defaultClearanceTypeSeeds.length));
      expect(
        clearanceTypes
            .singleWhere(
              (clearanceType) =>
                  clearanceType.code == SeedClearanceCodes.fundamentals2026,
            )
            .active,
        isFalse,
      );

      final roleIds = roles.map((role) => role.id).toSet();
      final clearanceTypeIds = clearanceTypes
          .map((clearanceType) => clearanceType.id)
          .toSet();
      expect(
        requirements,
        hasLength(defaultRoleClearanceRequirementSeeds.length),
      );
      expect(
        requirements.every(
          (requirement) => requirement.leagueId == result.leagueId,
        ),
        isTrue,
      );
      expect(
        requirements.every((requirement) => requirement.seasonId == null),
        isTrue,
      );
      expect(
        requirements.every(
          (requirement) => roleIds.contains(requirement.roleId),
        ),
        isTrue,
      );
      expect(
        requirements.every(
          (requirement) =>
              clearanceTypeIds.contains(requirement.clearanceTypeId),
        ),
        isTrue,
      );

      expect(users, hasLength(1));
      expect(users.single.id, result.ownerUserId);
      expect(users.single.leagueId, result.leagueId);
      expect(users.single.role, LeagueOnboardingRepository.ownerRole);
      expect(
        users.single.authProvider,
        LeagueOnboardingRepository.localPinAuthProvider,
      );
      expect(users.single.localPasscodeHash, 'hashed-pin');

      final expectedAuditCount =
          1 +
          selectedDivisions.length +
          defaultRoleSeeds.length +
          defaultClearanceTypeSeeds.length +
          defaultRoleClearanceRequirementSeeds.length +
          1;
      expect(auditLogs, hasLength(expectedAuditCount));
      expect(
        auditLogs.every(
          (auditLog) =>
              auditLog.action == LeagueOnboardingRepository.createAction &&
              auditLog.leagueId == result.leagueId,
        ),
        isTrue,
      );
      expect(
        auditLogs.where((auditLog) => auditLog.entity == 'League'),
        hasLength(1),
      );
      expect(
        auditLogs.where((auditLog) => auditLog.entity == 'Division'),
        hasLength(3),
      );
      expect(
        auditLogs.where((auditLog) => auditLog.entity == 'Role'),
        hasLength(9),
      );
      expect(
        auditLogs.where((auditLog) => auditLog.entity == 'ClearanceType'),
        hasLength(12),
      );
      expect(
        auditLogs.where(
          (auditLog) => auditLog.entity == 'RoleClearanceRequirement',
        ),
        hasLength(defaultRoleClearanceRequirementSeeds.length),
      );
      expect(
        auditLogs.where((auditLog) => auditLog.entity == 'User'),
        hasLength(1),
      );
      final userAuditLog = auditLogs.singleWhere(
        (auditLog) => auditLog.entity == 'User',
      );
      final userAuditAfter =
          jsonDecode(userAuditLog.afterJson!) as Map<String, dynamic>;
      expect(userAuditAfter.containsKey('localPasscodeHash'), isFalse);
      expect(userAuditAfter.containsKey('passwordHash'), isFalse);
    });

    test('rejects onboarding with no selected divisions', () async {
      await expectLater(
        repository.bootstrapLeague(
          leagueName: 'Mission Trails Little League',
          divisions: const [],
          ownerEmail: 'owner@example.com',
          ownerName: 'League Owner',
          ownerPasscodeHash: 'hashed-pin',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deduplicates blank and repeated division entries', () async {
      final result = await repository.bootstrapLeague(
        leagueName: 'Mission Trails Little League',
        divisions: const [
          OnboardingDivisionInput(name: 'Majors', sortOrder: 20),
          OnboardingDivisionInput(name: '  majors  ', sortOrder: 30),
          OnboardingDivisionInput(name: ' ', sortOrder: 40),
          OnboardingDivisionInput(name: 'Farm', sortOrder: 10),
        ],
        ownerEmail: 'owner@example.com',
        ownerName: 'League Owner',
        ownerPasscodeHash: 'hashed-pin',
      );

      final divisions =
          await (db.select(db.divisions)
                ..where((division) => division.leagueId.equals(result.leagueId))
                ..orderBy([
                  (division) => OrderingTerm(expression: division.sortOrder),
                ]))
              .get();

      expect(divisions.map((division) => division.name), ['Farm', 'Majors']);
    });
  });
}

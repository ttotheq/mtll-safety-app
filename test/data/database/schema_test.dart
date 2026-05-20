import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/data/database/app_database.dart';
import 'package:mtll_safety_app/data/database/seeds/clearance_seed_data.dart';
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

  group('AppDatabase schema (Sprint 1 tickets #1-#6)', () {
    test('schema includes no player-data tables', () {
      final tableNames = db.allTables.map((table) => table.actualTableName);
      final disallowedTokens = [
        'player',
        'roster',
        'minor',
        'athlete',
        'draft',
        'evaluation',
        'registration',
      ];
      final disallowedPattern = RegExp(
        '(^|_)(${disallowedTokens.join('|')})s?(\$|_)',
      );

      final violatingTables = tableNames
          .where((tableName) => disallowedPattern.hasMatch(tableName))
          .toList();

      expect(
        violatingTables,
        isEmpty,
        reason:
            'Schema must not include player-data tables. Found: '
            '${violatingTables.join(', ')}',
      );
    });

    test(
      'schema includes leagues, seasons, divisions, teams, volunteers, roles, volunteer_assignments, clearance_types, role_clearance_requirements, volunteer_clearances, evidence_files, exemptions, activity_logs, users, audit_log, audit_log_chain',
      () {
        final names = db.allTables.map((t) => t.actualTableName).toSet();
        expect(
          names,
          containsAll([
            'leagues',
            'seasons',
            'divisions',
            'teams',
            'volunteers',
            'roles',
            'volunteer_assignments',
            'clearance_types',
            'role_clearance_requirements',
            'volunteer_clearances',
            'evidence_files',
            'exemptions',
            'activity_logs',
            'users',
            'audit_log',
            'audit_log_chain',
          ]),
        );
      },
    );

    test(
      'round-trip insert across League → Season → Division → Team → Volunteer → Role → VolunteerAssignment → ClearanceType → RoleClearanceRequirement → EvidenceFile → VolunteerClearance → Exemption → User → ActivityLog → AuditLog → AuditLogChain',
      () async {
        final leagueId = uuid.v7();
        final seasonId = uuid.v7();
        final divisionId = uuid.v7();
        final teamId = uuid.v7();
        final volunteerId = uuid.v7();
        final roleId = uuid.v7();
        final assignmentId = uuid.v7();
        final clearanceTypeId = uuid.v7();
        final requirementId = uuid.v7();
        final evidenceFileId = uuid.v7();
        final volunteerClearanceId = uuid.v7();
        final exemptionId = uuid.v7();
        final userId = uuid.v7();
        final activityLogId = uuid.v7();
        final auditLogId = uuid.v7();
        final auditLogChainId = uuid.v7();

        await db
            .into(db.leagues)
            .insert(
              LeaguesCompanion.insert(
                id: leagueId,
                name: 'Mission Trails Little League',
                shortName: const Value('MTLL'),
                district: const Value('D33'),
              ),
            );

        await db
            .into(db.seasons)
            .insert(
              SeasonsCompanion.insert(
                id: seasonId,
                leagueId: leagueId,
                name: '2026 Spring',
                year: 2026,
                term: 'Spring',
                startDate: DateTime.utc(2026, 2, 1),
                endDate: DateTime.utc(2026, 6, 15),
                isActive: const Value(true),
              ),
            );

        await db
            .into(db.divisions)
            .insert(
              DivisionsCompanion.insert(
                id: divisionId,
                leagueId: leagueId,
                name: 'Majors',
                sortOrder: 4,
                ageMin: const Value(10),
                ageMax: const Value(12),
              ),
            );

        await db
            .into(db.teams)
            .insert(
              TeamsCompanion.insert(
                id: teamId,
                leagueId: leagueId,
                seasonId: seasonId,
                divisionId: divisionId,
                name: 'BONILLA',
                displayName: 'MAJORS - BONILLA',
              ),
            );

        await db
            .into(db.volunteers)
            .insert(
              VolunteersCompanion.insert(
                id: volunteerId,
                leagueId: leagueId,
                firstName: 'Jamie',
                lastName: 'Volunteer',
                email: const Value('jamie@example.com'),
              ),
            );

        await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                id: userId,
                leagueId: leagueId,
                email: 'owner@example.com',
                name: 'Ty Quan',
                role: 'OWNER',
                authProvider: 'LOCAL',
              ),
            );

        await db
            .into(db.roles)
            .insert(
              RolesCompanion.insert(
                id: roleId,
                leagueId: leagueId,
                name: 'Manager',
                isOnField: true,
                permitsMinor: false,
                sortOrder: 10,
              ),
            );

        await db
            .into(db.volunteerAssignments)
            .insert(
              VolunteerAssignmentsCompanion.insert(
                id: assignmentId,
                leagueId: leagueId,
                volunteerId: volunteerId,
                teamId: Value(teamId),
                seasonId: seasonId,
                roleId: roleId,
                startedAt: DateTime.utc(2026, 2, 1),
                status: 'Active',
              ),
            );

        final team = await (db.select(
          db.teams,
        )..where((t) => t.id.equals(teamId))).getSingle();
        expect(team.name, 'BONILLA');
        expect(team.displayName, 'MAJORS - BONILLA');
        expect(team.leagueId, leagueId);
        expect(team.seasonId, seasonId);
        expect(team.divisionId, divisionId);

        final volunteer = await (db.select(
          db.volunteers,
        )..where((v) => v.id.equals(volunteerId))).getSingle();
        expect(volunteer.email, 'jamie@example.com');
        expect(volunteer.isFirstTime, isFalse);
        expect(volunteer.followUpFlag, isFalse);
        expect(volunteer.isJunior, isFalse);

        final role = await (db.select(
          db.roles,
        )..where((r) => r.id.equals(roleId))).getSingle();
        expect(role.name, 'Manager');
        expect(role.permitsMinor, isFalse);

        final assignment = await (db.select(
          db.volunteerAssignments,
        )..where((a) => a.id.equals(assignmentId))).getSingle();
        expect(assignment.leagueId, leagueId);
        expect(assignment.volunteerId, volunteerId);
        expect(assignment.teamId, teamId);
        expect(assignment.roleId, roleId);
        expect(assignment.status, 'Active');

        await db
            .into(db.clearanceTypes)
            .insert(
              ClearanceTypesCompanion.insert(
                id: clearanceTypeId,
                leagueId: leagueId,
                code: 'BACKGROUND_CHECK',
                name: 'Background Check',
                category: 'ANNUAL',
                isRecurring: true,
                defaultValidityMonths: const Value(12),
                evidenceRequired: true,
                sortOrder: 10,
              ),
            );

        await db
            .into(db.roleClearanceRequirements)
            .insert(
              RoleClearanceRequirementsCompanion.insert(
                id: requirementId,
                leagueId: leagueId,
                roleId: roleId,
                clearanceTypeId: clearanceTypeId,
                requirement: 'REQUIRED',
                minAge: const Value(18),
              ),
            );

        await db
            .into(db.evidenceFiles)
            .insert(
              EvidenceFilesCompanion.insert(
                id: evidenceFileId,
                leagueId: leagueId,
                volunteerId: volunteerId,
                filenameOriginal: 'background-check.pdf',
                mime: 'application/pdf',
                sizeBytes: 4096,
                sha256: 'abc123deadbeef',
                storageUri: const Value(
                  'evidence/league/2026/background-check.enc',
                ),
                encryptionKdf: 'argon2id',
                fileEncryptionNonce: Uint8List.fromList(
                  List<int>.generate(24, (i) => i),
                ),
                keyWrapNonce: Uint8List.fromList(
                  List<int>.generate(24, (i) => 24 - i),
                ),
                wrappedFileKey: Uint8List.fromList(
                  List<int>.generate(48, (i) => (i * 3) % 256),
                ),
                uploadedAt: DateTime.utc(2026, 2, 9, 10, 30),
                uploadedByUserId: userId,
              ),
            );

        final evidenceFile = await (db.select(
          db.evidenceFiles,
        )..where((e) => e.id.equals(evidenceFileId))).getSingle();
        expect(evidenceFile.sha256, 'abc123deadbeef');
        expect(
          evidenceFile.storageUri,
          'evidence/league/2026/background-check.enc',
        );
        expect(evidenceFile.fileEncryptionNonce, hasLength(24));
        expect(evidenceFile.keyWrapNonce, hasLength(24));
        expect(evidenceFile.wrappedFileKey, hasLength(48));
        expect(evidenceFile.deletedAt, equals(null));

        await db
            .into(db.volunteerClearances)
            .insert(
              VolunteerClearancesCompanion.insert(
                id: volunteerClearanceId,
                leagueId: leagueId,
                volunteerId: volunteerId,
                clearanceTypeId: clearanceTypeId,
                seasonId: Value(seasonId),
                status: 'WAIVED',
                verifiedByUserId: Value(userId),
                evidenceFileId: Value(evidenceFileId),
                source: 'MANUAL',
              ),
            );

        await db
            .into(db.exemptions)
            .insert(
              ExemptionsCompanion.insert(
                id: exemptionId,
                leagueId: leagueId,
                volunteerClearanceId: volunteerClearanceId,
                reason: 'District waiver on file',
                grantingAuthority: 'District 33',
                grantedOn: DateTime.utc(2026, 2, 10),
                evidenceFileId: Value(evidenceFileId),
              ),
            );

        final clearanceType = await (db.select(
          db.clearanceTypes,
        )..where((c) => c.id.equals(clearanceTypeId))).getSingle();
        expect(clearanceType.code, 'BACKGROUND_CHECK');
        expect(clearanceType.defaultValidityMonths, 12);
        expect(clearanceType.evidenceRequired, isTrue);

        final requirement = await (db.select(
          db.roleClearanceRequirements,
        )..where((r) => r.id.equals(requirementId))).getSingle();
        expect(requirement.requirement, 'REQUIRED');
        expect(requirement.minAge, 18);

        final volunteerClearance = await (db.select(
          db.volunteerClearances,
        )..where((vc) => vc.id.equals(volunteerClearanceId))).getSingle();
        expect(volunteerClearance.status, 'WAIVED');
        expect(volunteerClearance.leagueId, leagueId);
        expect(volunteerClearance.source, 'MANUAL');
        expect(volunteerClearance.evidenceFileId, evidenceFileId);

        final exemption = await (db.select(
          db.exemptions,
        )..where((e) => e.id.equals(exemptionId))).getSingle();
        expect(exemption.reason, 'District waiver on file');
        expect(exemption.grantingAuthority, 'District 33');
        expect(exemption.leagueId, leagueId);
        expect(exemption.evidenceFileId, evidenceFileId);

        final user = await (db.select(
          db.users,
        )..where((u) => u.id.equals(userId))).getSingle();
        expect(user.email, 'owner@example.com');
        expect(user.role, 'OWNER');

        await db
            .into(db.activityLogs)
            .insert(
              ActivityLogsCompanion.insert(
                id: activityLogId,
                leagueId: leagueId,
                volunteerId: volunteerId,
                actorUserId: userId,
                kind: 'WAIVER_GRANTED',
                body: 'District waiver recorded',
                occurredAt: DateTime.utc(2026, 2, 10, 12),
                relatedClearanceId: Value(volunteerClearanceId),
              ),
            );

        final activityLog = await (db.select(
          db.activityLogs,
        )..where((a) => a.id.equals(activityLogId))).getSingle();
        expect(activityLog.kind, 'WAIVER_GRANTED');
        expect(activityLog.actorUserId, userId);

        await db
            .into(db.auditLogs)
            .insert(
              AuditLogsCompanion.insert(
                id: auditLogId,
                leagueId: leagueId,
                userId: Value(userId),
                at: DateTime.utc(2026, 2, 10, 12, 1),
                entity: 'VolunteerClearance',
                entityId: volunteerClearanceId,
                action: 'STATUS_CHANGE',
                beforeJson: const Value('{"status":"PENDING"}'),
                afterJson: const Value('{"status":"WAIVED"}'),
              ),
            );

        final auditLog = await (db.select(
          db.auditLogs,
        )..where((a) => a.id.equals(auditLogId))).getSingle();
        expect(auditLog.action, 'STATUS_CHANGE');
        expect(auditLog.userId, userId);

        await db
            .into(db.auditLogChains)
            .insert(
              AuditLogChainsCompanion.insert(
                id: auditLogChainId,
                chainDate: DateTime.utc(2026, 2, 10),
                rowCount: 1,
                dayHash: 'dayhash',
                prevHash: const Value(null),
                chainHash: 'chainhash',
                sealedAt: DateTime.utc(2026, 2, 11, 0, 5),
              ),
            );

        final auditLogChain = await (db.select(
          db.auditLogChains,
        )..where((c) => c.id.equals(auditLogChainId))).getSingle();
        expect(auditLogChain.rowCount, 1);
        expect(auditLogChain.prevHash, equals(null));
        expect(auditLogChain.chainHash, 'chainhash');

        final league = await (db.select(
          db.leagues,
        )..where((l) => l.id.equals(leagueId))).getSingle();
        expect(league.shortName, 'MTLL');
        expect(league.timezone, 'America/Los_Angeles');
        expect(league.locale, 'en-US');
      },
    );

    test('(league_id, lower(email)) unique on User', () async {
      final leagueId = uuid.v7();
      await db
          .into(db.leagues)
          .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: uuid.v7(),
              leagueId: leagueId,
              email: 'Owner@Example.com',
              name: 'Owner',
              role: 'OWNER',
              authProvider: 'LOCAL',
            ),
          );
      await expectLater(
        db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                email: 'owner@example.com',
                name: 'Duplicate Owner',
                role: 'ADMIN',
                authProvider: 'LOCAL',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('(league_id, year, term) unique on Season', () async {
      final leagueId = uuid.v7();
      await db
          .into(db.leagues)
          .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
      await db
          .into(db.seasons)
          .insert(
            SeasonsCompanion.insert(
              id: uuid.v7(),
              leagueId: leagueId,
              name: '2026 Spring',
              year: 2026,
              term: 'Spring',
              startDate: DateTime.utc(2026, 2, 1),
              endDate: DateTime.utc(2026, 6, 15),
            ),
          );
      await expectLater(
        db
            .into(db.seasons)
            .insert(
              SeasonsCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                name: 'duplicate spring',
                year: 2026,
                term: 'Spring',
                startDate: DateTime.utc(2026, 2, 1),
                endDate: DateTime.utc(2026, 6, 15),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('(league_id, code) unique on ClearanceType', () async {
      final leagueId = uuid.v7();
      await db
          .into(db.leagues)
          .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
      await db
          .into(db.clearanceTypes)
          .insert(
            ClearanceTypesCompanion.insert(
              id: uuid.v7(),
              leagueId: leagueId,
              code: 'LIVESCAN',
              name: 'LiveScan',
              category: 'ONE_TIME',
              isRecurring: false,
              defaultValidityMonths: const Value(24),
              evidenceRequired: true,
              sortOrder: 20,
            ),
          );
      await expectLater(
        db
            .into(db.clearanceTypes)
            .insert(
              ClearanceTypesCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                code: 'LIVESCAN',
                name: 'LiveScan duplicate',
                category: 'ONE_TIME',
                isRecurring: false,
                defaultValidityMonths: const Value(24),
                evidenceRequired: true,
                sortOrder: 21,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'RoleClearanceRequirement uniqueness treats null season_id as a value',
      () async {
        final leagueId = uuid.v7();
        final roleId = uuid.v7();
        final clearanceTypeId = uuid.v7();

        await db
            .into(db.leagues)
            .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
        await db
            .into(db.roles)
            .insert(
              RolesCompanion.insert(
                id: roleId,
                leagueId: leagueId,
                name: 'Manager',
                isOnField: true,
                permitsMinor: false,
                sortOrder: 10,
              ),
            );
        await db
            .into(db.clearanceTypes)
            .insert(
              ClearanceTypesCompanion.insert(
                id: clearanceTypeId,
                leagueId: leagueId,
                code: 'BACKGROUND_CHECK',
                name: 'Background Check',
                category: 'ANNUAL',
                isRecurring: true,
                defaultValidityMonths: const Value(12),
                evidenceRequired: true,
                sortOrder: 10,
              ),
            );

        await db
            .into(db.roleClearanceRequirements)
            .insert(
              RoleClearanceRequirementsCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                roleId: roleId,
                clearanceTypeId: clearanceTypeId,
                requirement: 'REQUIRED',
              ),
            );

        await expectLater(
          db
              .into(db.roleClearanceRequirements)
              .insert(
                RoleClearanceRequirementsCompanion.insert(
                  id: uuid.v7(),
                  leagueId: leagueId,
                  roleId: roleId,
                  clearanceTypeId: clearanceTypeId,
                  requirement: 'OPTIONAL',
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      'VolunteerClearance uniqueness treats null season_id as a value',
      () async {
        final leagueId = uuid.v7();
        final volunteerId = uuid.v7();
        final clearanceTypeId = uuid.v7();

        await db
            .into(db.leagues)
            .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
        await db
            .into(db.volunteers)
            .insert(
              VolunteersCompanion.insert(
                id: volunteerId,
                leagueId: leagueId,
                firstName: 'Morgan',
                lastName: 'Volunteer',
              ),
            );
        await db
            .into(db.clearanceTypes)
            .insert(
              ClearanceTypesCompanion.insert(
                id: clearanceTypeId,
                leagueId: leagueId,
                code: 'CONCUSSION',
                name: 'Concussion Training',
                category: 'ONE_TIME',
                isRecurring: false,
                evidenceRequired: true,
                sortOrder: 60,
              ),
            );

        await db
            .into(db.volunteerClearances)
            .insert(
              VolunteerClearancesCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                volunteerId: volunteerId,
                clearanceTypeId: clearanceTypeId,
                status: 'COMPLETE',
                completedOn: Value(DateTime.utc(2026, 2, 1)),
                source: 'MANUAL',
              ),
            );

        await expectLater(
          db
              .into(db.volunteerClearances)
              .insert(
                VolunteerClearancesCompanion.insert(
                  id: uuid.v7(),
                  leagueId: leagueId,
                  volunteerId: volunteerId,
                  clearanceTypeId: clearanceTypeId,
                  status: 'PENDING',
                  source: 'CSV_IMPORT',
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('AuditLogChain chain_date is unique', () async {
      await db
          .into(db.auditLogChains)
          .insert(
            AuditLogChainsCompanion.insert(
              id: uuid.v7(),
              chainDate: DateTime.utc(2026, 2, 10),
              rowCount: 1,
              dayHash: 'dayhash1',
              prevHash: const Value(null),
              chainHash: 'chainhash1',
              sealedAt: DateTime.utc(2026, 2, 11),
            ),
          );
      await expectLater(
        db
            .into(db.auditLogChains)
            .insert(
              AuditLogChainsCompanion.insert(
                id: uuid.v7(),
                chainDate: DateTime.utc(2026, 2, 10),
                rowCount: 2,
                dayHash: 'dayhash2',
                prevHash: const Value('dayhash1'),
                chainHash: 'chainhash2',
                sealedAt: DateTime.utc(2026, 2, 12),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'partial-unique enforces at-most-one active season per league',
      () async {
        final leagueId = uuid.v7();
        await db
            .into(db.leagues)
            .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
        await db
            .into(db.seasons)
            .insert(
              SeasonsCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                name: '2026 Spring',
                year: 2026,
                term: 'Spring',
                startDate: DateTime.utc(2026, 2, 1),
                endDate: DateTime.utc(2026, 6, 15),
                isActive: const Value(true),
              ),
            );
        await expectLater(
          db
              .into(db.seasons)
              .insert(
                SeasonsCompanion.insert(
                  id: uuid.v7(),
                  leagueId: leagueId,
                  name: '2026 Fall',
                  year: 2026,
                  term: 'Fall',
                  startDate: DateTime.utc(2026, 9, 1),
                  endDate: DateTime.utc(2026, 11, 30),
                  isActive: const Value(true),
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('(league_id, name) unique on Division', () async {
      final leagueId = uuid.v7();
      await db
          .into(db.leagues)
          .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
      await db
          .into(db.divisions)
          .insert(
            DivisionsCompanion.insert(
              id: uuid.v7(),
              leagueId: leagueId,
              name: 'Majors',
              sortOrder: 4,
            ),
          );
      await expectLater(
        db
            .into(db.divisions)
            .insert(
              DivisionsCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                name: 'Majors',
                sortOrder: 5,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('(league_id, name) unique on Role', () async {
      final leagueId = uuid.v7();
      await db
          .into(db.leagues)
          .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
      await db
          .into(db.roles)
          .insert(
            RolesCompanion.insert(
              id: uuid.v7(),
              leagueId: leagueId,
              name: 'Junior Umpire',
              isOnField: true,
              permitsMinor: true,
              sortOrder: 80,
            ),
          );
      await expectLater(
        db
            .into(db.roles)
            .insert(
              RolesCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                name: 'Junior Umpire',
                isOnField: true,
                permitsMinor: true,
                sortOrder: 81,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'active VolunteerAssignment uniqueness treats null team_id as a value',
      () async {
        final leagueId = uuid.v7();
        final seasonId = uuid.v7();
        final volunteerId = uuid.v7();
        final roleId = uuid.v7();

        await db
            .into(db.leagues)
            .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
        await db
            .into(db.seasons)
            .insert(
              SeasonsCompanion.insert(
                id: seasonId,
                leagueId: leagueId,
                name: '2026 Spring',
                year: 2026,
                term: 'Spring',
                startDate: DateTime.utc(2026, 2, 1),
                endDate: DateTime.utc(2026, 6, 15),
              ),
            );
        await db
            .into(db.volunteers)
            .insert(
              VolunteersCompanion.insert(
                id: volunteerId,
                leagueId: leagueId,
                firstName: 'Taylor',
                lastName: 'Umpire',
              ),
            );
        await db
            .into(db.roles)
            .insert(
              RolesCompanion.insert(
                id: roleId,
                leagueId: leagueId,
                name: 'Umpire',
                isOnField: true,
                permitsMinor: false,
                sortOrder: 70,
              ),
            );

        await db
            .into(db.volunteerAssignments)
            .insert(
              VolunteerAssignmentsCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                volunteerId: volunteerId,
                seasonId: seasonId,
                roleId: roleId,
                startedAt: DateTime.utc(2026, 2, 1),
                status: 'Active',
              ),
            );

        await expectLater(
          db
              .into(db.volunteerAssignments)
              .insert(
                VolunteerAssignmentsCompanion.insert(
                  id: uuid.v7(),
                  leagueId: leagueId,
                  volunteerId: volunteerId,
                  seasonId: seasonId,
                  roleId: roleId,
                  startedAt: DateTime.utc(2026, 2, 2),
                  status: 'Active',
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        await db
            .into(db.volunteerAssignments)
            .insert(
              VolunteerAssignmentsCompanion.insert(
                id: uuid.v7(),
                leagueId: leagueId,
                volunteerId: volunteerId,
                seasonId: seasonId,
                roleId: roleId,
                startedAt: DateTime.utc(2025, 9, 1),
                endedAt: Value(DateTime.utc(2025, 12, 31)),
                status: 'Removed',
              ),
            );
      },
    );
  });

  group('clearance seed catalog', () {
    test('contains 12 locked clearance types', () {
      expect(defaultClearanceTypeSeeds, hasLength(12));

      final fundamentals = defaultClearanceTypeSeeds.singleWhere(
        (seed) => seed.code == SeedClearanceCodes.fundamentals2026,
      );
      expect(fundamentals.active, isFalse);
      expect(fundamentals.category, SeedClearanceCategories.seasonSpecific);

      final livescan = defaultClearanceTypeSeeds.singleWhere(
        (seed) => seed.code == SeedClearanceCodes.livescan,
      );
      expect(livescan.defaultValidityMonths, 24);
      expect(livescan.isRecurring, isFalse);
    });

    test(
      'contains the locked default matrix for the 8 requirement-bearing roles',
      () {
        expect(defaultRoleClearanceRequirementSeeds, hasLength(96));

        final managerFirstAid = defaultRoleClearanceRequirementSeeds
            .singleWhere(
              (seed) =>
                  seed.roleName == SeedRoleNames.manager &&
                  seed.clearanceCode == SeedClearanceCodes.firstAid,
            );
        expect(
          managerFirstAid.requirement,
          SeedRequirementLevels.conditionalOk,
        );

        final umpireBackgroundCheck = defaultRoleClearanceRequirementSeeds
            .singleWhere(
              (seed) =>
                  seed.roleName == SeedRoleNames.umpire &&
                  seed.clearanceCode == SeedClearanceCodes.backgroundCheck,
            );
        expect(
          umpireBackgroundCheck.requirement,
          SeedRequirementLevels.required,
        );
        expect(umpireBackgroundCheck.minAge, 18);

        final juniorUmpireSafety2026 = defaultRoleClearanceRequirementSeeds
            .singleWhere(
              (seed) =>
                  seed.roleName == SeedRoleNames.juniorUmpire &&
                  seed.clearanceCode == SeedClearanceCodes.safety2026,
            );
        expect(
          juniorUmpireSafety2026.requirement,
          SeedRequirementLevels.notApplicable,
        );
      },
    );

    test('AuditLog UPDATE and DELETE are blocked by triggers', () async {
      final leagueId = uuid.v7();
      final auditLogId = uuid.v7();

      await db
          .into(db.leagues)
          .insert(LeaguesCompanion.insert(id: leagueId, name: 'Test League'));
      await db
          .into(db.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              id: auditLogId,
              leagueId: leagueId,
              at: DateTime.utc(2026, 2, 10, 12),
              entity: 'League',
              entityId: leagueId,
              action: 'CREATE',
            ),
          );

      await expectLater(
        db.customStatement(
          "UPDATE audit_log SET action = 'FAKE' WHERE id = '$auditLogId'",
        ),
        throwsA(isA<SqliteException>()),
      );

      await expectLater(
        db.customStatement("DELETE FROM audit_log WHERE id = '$auditLogId'"),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}

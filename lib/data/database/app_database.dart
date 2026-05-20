import 'package:drift/drift.dart';

import 'tables/activity_logs.dart';
import 'tables/audit_log_chains.dart';
import 'tables/audit_logs.dart';
import 'tables/clearance_types.dart';
import 'tables/divisions.dart';
import 'tables/evidence_files.dart';
import 'tables/exemptions.dart';
import 'tables/leagues.dart';
import 'tables/roles.dart';
import 'tables/role_clearance_requirements.dart';
import 'tables/seasons.dart';
import 'tables/teams.dart';
import 'tables/users.dart';
import 'tables/volunteer_assignments.dart';
import 'tables/volunteer_clearances.dart';
import 'tables/volunteers.dart';

part 'app_database.g.dart';

// MTLL Safety Clearance App — root Drift database.
//
// Sprint 1 ticket #1 establishes only the entity-chain root: League → Season
// → Division → Team. Volunteers, clearances, evidence, audit log, and the
// supporting tables arrive in tickets #2–#5. Schema version bumps once per
// ticket so forward-only migrations stay traceable to EXECUTION-PLAN §6.7.
@DriftDatabase(
  tables: [
    Leagues,
    Seasons,
    Divisions,
    Teams,
    Volunteers,
    Roles,
    VolunteerAssignments,
    ClearanceTypes,
    RoleClearanceRequirements,
    VolunteerClearances,
    EvidenceFiles,
    Exemptions,
    ActivityLogs,
    Users,
    AuditLogs,
    AuditLogChains,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createManualIndexes();
      await _createAuditImmutabilityTriggers();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(volunteers);
        await m.createTable(roles);
        await _migrateTeamsToV2(m);
        await m.createTable(volunteerAssignments);
      }
      if (from < 3) {
        await m.createTable(clearanceTypes);
        await m.createTable(roleClearanceRequirements);
        await m.createTable(volunteerClearances);
        await m.createTable(exemptions);
      }
      if (from < 4) {
        await m.createTable(evidenceFiles);
        await _createManualIndexes();
      }
      if (from < 5) {
        await m.createTable(activityLogs);
        await m.createTable(users);
        await m.createTable(auditLogs);
        await m.createTable(auditLogChains);
        await _createManualIndexes();
      }
      if (from < 6) {
        await _createAuditImmutabilityTriggers();
      }
    },
  );

  Future<void> _createManualIndexes() async {
    // Partial unique index: at most one active season per league.
    // Drift's uniqueKeys getter cannot express a WHERE predicate, so
    // we apply the constraint via raw DDL. See design-notes §1.2.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS seasons_one_active_per_league '
      'ON seasons (league_id) WHERE is_active = 1',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS teams_league_id_idx '
      'ON teams (league_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS teams_manager_volunteer_id_idx '
      'ON teams (manager_volunteer_id)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteers_league_id_idx '
      'ON volunteers (league_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteers_league_email_idx '
      'ON volunteers (league_id, lower(email))',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteers_league_name_idx '
      'ON volunteers (league_id, lower(last_name), lower(first_name))',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteers_league_phone_idx '
      'ON volunteers (league_id, phone_e164)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteers_external_pm_id_idx '
      'ON volunteers (external_pm_id)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteer_assignments_league_id_idx '
      'ON volunteer_assignments (league_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteer_assignments_volunteer_season_idx '
      'ON volunteer_assignments (volunteer_id, season_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteer_assignments_team_season_idx '
      'ON volunteer_assignments (team_id, season_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS volunteer_assignments_one_active_idx '
      'ON volunteer_assignments '
      '(volunteer_id, ifnull(team_id, \'\'), role_id, season_id) '
      'WHERE ended_at IS NULL',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS clearance_types_league_id_idx '
      'ON clearance_types (league_id)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS role_clearance_requirements_league_id_idx '
      'ON role_clearance_requirements (league_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS role_clearance_requirements_resolved_idx '
      'ON role_clearance_requirements '
      '(league_id, ifnull(season_id, \'\'), role_id, clearance_type_id)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteer_clearances_league_id_idx '
      'ON volunteer_clearances (league_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteer_clearances_status_idx '
      'ON volunteer_clearances (status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteer_clearances_expires_on_idx '
      'ON volunteer_clearances (expires_on)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS volunteer_clearances_volunteer_id_idx '
      'ON volunteer_clearances (volunteer_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS volunteer_clearances_unique_idx '
      'ON volunteer_clearances '
      '(volunteer_id, clearance_type_id, ifnull(season_id, \'\'))',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS exemptions_league_id_idx '
      'ON exemptions (league_id)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS evidence_files_league_volunteer_idx '
      'ON evidence_files (league_id, volunteer_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS evidence_files_sha256_idx '
      'ON evidence_files (sha256)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS activity_logs_volunteer_occurred_idx '
      'ON activity_logs (volunteer_id, occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS activity_logs_league_occurred_idx '
      'ON activity_logs (league_id, occurred_at DESC)',
    );

    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS users_league_email_idx '
      'ON users (league_id, lower(email))',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS audit_log_league_entity_idx '
      'ON audit_log (league_id, entity, entity_id, at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS audit_log_league_at_idx '
      'ON audit_log (league_id, at DESC)',
    );
  }

  Future<void> _createAuditImmutabilityTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS audit_log_no_update
      BEFORE UPDATE ON audit_log
      BEGIN
        SELECT RAISE(ABORT, 'AuditLog rows are immutable');
      END;
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS audit_log_no_delete
      BEFORE DELETE ON audit_log
      BEGIN
        SELECT RAISE(ABORT, 'AuditLog rows are immutable');
      END;
    ''');
  }

  Future<void> _migrateTeamsToV2(Migrator m) async {
    await customStatement('ALTER TABLE teams RENAME TO teams_v1');
    await m.createTable(teams);
    await customStatement(
      'INSERT INTO teams ('
      'id, league_id, season_id, division_id, name, display_name, '
      'manager_volunteer_id, color, created_at, updated_at, '
      'created_by_user_id, updated_by_user_id'
      ') '
      'SELECT '
      't.id, s.league_id, t.season_id, t.division_id, t.name, '
      't.display_name, t.manager_volunteer_id, t.color, t.created_at, '
      't.updated_at, t.created_by_user_id, t.updated_by_user_id '
      'FROM teams_v1 t '
      'JOIN seasons s ON s.id = t.season_id',
    );
    await customStatement('DROP TABLE teams_v1');
  }
}

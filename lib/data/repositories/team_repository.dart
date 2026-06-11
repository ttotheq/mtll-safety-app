import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'league_scoped_repository.dart';

class TeamRepository extends LeagueScopedRepository {
  TeamRepository({required super.db, required super.sessionContext});

  Future<List<TeamRow>> listAll() {
    return (db.select(db.teams)
          ..where((team) => tenantFilter(team.leagueId))
          ..orderBy([
            (team) => OrderingTerm(expression: team.displayName),
            (team) => OrderingTerm(expression: team.name),
          ]))
        .get();
  }

  Future<TeamRow?> getById(String id) async {
    final row = await _findById(id);
    if (row == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'Team',
      entityId: row.id,
      rowLeagueId: row.leagueId,
    );
    return row;
  }

  Future<TeamRow> create({
    required String seasonId,
    required String divisionId,
    required String name,
    String? managerVolunteerId,
    String? color,
  }) async {
    final teamName = requireNonBlank(name, 'name');
    final division = await _requireDivision(divisionId);

    final now = currentTimestamp();
    final row = TeamRow(
      id: newId(),
      leagueId: sessionContext.leagueId,
      seasonId: requireNonBlank(seasonId, 'seasonId'),
      divisionId: division.id,
      name: teamName,
      displayName: _displayName(division.name, teamName),
      managerVolunteerId: normalizeNullable(managerVolunteerId),
      color: normalizeNullable(color),
      createdAt: now,
      updatedAt: now,
      createdByUserId: sessionContext.userId,
      updatedByUserId: sessionContext.userId,
    );

    await db
        .into(db.teams)
        .insert(
          TeamsCompanion.insert(
            id: row.id,
            leagueId: row.leagueId,
            seasonId: row.seasonId,
            divisionId: row.divisionId,
            name: row.name,
            displayName: row.displayName,
            managerVolunteerId: Value(row.managerVolunteerId),
            color: Value(row.color),
            createdAt: Value(row.createdAt),
            updatedAt: Value(row.updatedAt),
            createdByUserId: Value(row.createdByUserId),
            updatedByUserId: Value(row.updatedByUserId),
          ),
        );

    await writeAuditLog(
      entityName: 'Team',
      entityId: row.id,
      action: LeagueScopedRepository.createAction,
      after: row.toJson(),
      at: now,
    );
    return row;
  }

  Future<TeamRow?> update({
    required String id,
    required String divisionId,
    required String name,
    String? managerVolunteerId,
    String? color,
  }) async {
    final existing = await _findById(id);
    if (existing == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'Team',
      entityId: existing.id,
      rowLeagueId: existing.leagueId,
    );

    final teamName = requireNonBlank(name, 'name');
    final division = await _requireDivision(divisionId);

    final now = currentTimestamp();
    await (db.update(db.teams)..where(
          (team) => team.id.equals(id) & tenantFilter(team.leagueId),
        ))
        .write(
          TeamsCompanion(
            divisionId: Value(division.id),
            name: Value(teamName),
            displayName: Value(_displayName(division.name, teamName)),
            managerVolunteerId: Value(normalizeNullable(managerVolunteerId)),
            color: Value(normalizeNullable(color)),
            updatedAt: Value(now),
            updatedByUserId: Value(sessionContext.userId),
          ),
        );

    final updated = await (db.select(
      db.teams,
    )..where((team) => team.id.equals(id))).getSingle();

    await writeAuditLog(
      entityName: 'Team',
      entityId: id,
      action: LeagueScopedRepository.updateAction,
      before: existing.toJson(),
      after: updated.toJson(),
      at: now,
    );
    return updated;
  }

  // display_name is denormalized on write per design-notes §1.4 —
  // workbook-compatible label, e.g. "MAJORS - BONILLA".
  String _displayName(String divisionName, String teamName) =>
      '${divisionName.toUpperCase()} - ${teamName.toUpperCase()}';

  Future<DivisionRow> _requireDivision(String divisionId) async {
    final id = requireNonBlank(divisionId, 'divisionId');
    final division = await (db.select(
      db.divisions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (division == null) {
      throw ArgumentError.value(divisionId, 'divisionId', 'unknown division');
    }

    await assertLeagueScope(
      entityName: 'Division',
      entityId: division.id,
      rowLeagueId: division.leagueId,
    );
    return division;
  }

  Future<TeamRow?> _findById(String id) {
    return (db.select(
      db.teams,
    )..where((team) => team.id.equals(id))).getSingleOrNull();
  }
}

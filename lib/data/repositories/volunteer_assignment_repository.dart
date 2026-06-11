import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'league_scoped_repository.dart';

// design-notes §1.7 — VolunteerAssignment.status enum.
abstract final class VolunteerAssignmentStatuses {
  static const active = 'ACTIVE';
  static const removed = 'REMOVED';
  static const replaced = 'REPLACED';

  static const all = {active, removed, replaced};
}

class VolunteerAssignmentRepository extends LeagueScopedRepository {
  VolunteerAssignmentRepository({
    required super.db,
    required super.sessionContext,
  });

  Future<List<VolunteerAssignmentRow>> listAll() {
    return (db.select(db.volunteerAssignments)
          ..where((assignment) => tenantFilter(assignment.leagueId))
          ..orderBy([
            (assignment) => OrderingTerm(expression: assignment.startedAt),
            (assignment) => OrderingTerm(expression: assignment.id),
          ]))
        .get();
  }

  Future<VolunteerAssignmentRow?> getById(String id) async {
    final row = await _findById(id);
    if (row == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'VolunteerAssignment',
      entityId: row.id,
      rowLeagueId: row.leagueId,
    );
    return row;
  }

  Future<VolunteerAssignmentRow> create({
    required String volunteerId,
    required String seasonId,
    required String roleId,
    required DateTime startedAt,
    String? teamId,
    String status = VolunteerAssignmentStatuses.active,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'VolunteerAssignment',
      operation: 'create',
    );

    final now = currentTimestamp();
    final row = VolunteerAssignmentRow(
      id: newId(),
      leagueId: sessionContext.leagueId,
      volunteerId: requireNonBlank(volunteerId, 'volunteerId'),
      teamId: normalizeNullable(teamId),
      seasonId: requireNonBlank(seasonId, 'seasonId'),
      roleId: requireNonBlank(roleId, 'roleId'),
      startedAt: startedAt,
      endedAt: null,
      status: _requireStatus(status),
      createdAt: now,
      updatedAt: now,
      createdByUserId: sessionContext.userId,
      updatedByUserId: sessionContext.userId,
    );

    await db
        .into(db.volunteerAssignments)
        .insert(
          VolunteerAssignmentsCompanion.insert(
            id: row.id,
            leagueId: row.leagueId,
            volunteerId: row.volunteerId,
            teamId: Value(row.teamId),
            seasonId: row.seasonId,
            roleId: row.roleId,
            startedAt: row.startedAt,
            endedAt: Value(row.endedAt),
            status: row.status,
            createdAt: Value(row.createdAt),
            updatedAt: Value(row.updatedAt),
            createdByUserId: Value(row.createdByUserId),
            updatedByUserId: Value(row.updatedByUserId),
          ),
        );

    await writeAuditLog(
      entityName: 'VolunteerAssignment',
      entityId: row.id,
      action: LeagueScopedRepository.createAction,
      after: row.toJson(),
      at: now,
    );
    return row;
  }

  Future<VolunteerAssignmentRow?> update({
    required String id,
    required String status,
    String? teamId,
    DateTime? endedAt,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'VolunteerAssignment',
      operation: 'update',
      entityId: id,
    );

    final existing = await _findById(id);
    if (existing == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'VolunteerAssignment',
      entityId: existing.id,
      rowLeagueId: existing.leagueId,
    );

    final now = currentTimestamp();
    await (db.update(db.volunteerAssignments)..where(
          (assignment) =>
              assignment.id.equals(id) & tenantFilter(assignment.leagueId),
        ))
        .write(
          VolunteerAssignmentsCompanion(
            teamId: Value(normalizeNullable(teamId)),
            status: Value(_requireStatus(status)),
            endedAt: Value(endedAt),
            updatedAt: Value(now),
            updatedByUserId: Value(sessionContext.userId),
          ),
        );

    final updated = await (db.select(
      db.volunteerAssignments,
    )..where((assignment) => assignment.id.equals(id))).getSingle();

    await writeAuditLog(
      entityName: 'VolunteerAssignment',
      entityId: id,
      action: LeagueScopedRepository.updateAction,
      before: existing.toJson(),
      after: updated.toJson(),
      at: now,
    );
    return updated;
  }

  String _requireStatus(String status) {
    final normalized = requireNonBlank(status, 'status');
    if (!VolunteerAssignmentStatuses.all.contains(normalized)) {
      throw ArgumentError.value(
        status,
        'status',
        'must be one of ${VolunteerAssignmentStatuses.all}',
      );
    }

    return normalized;
  }

  Future<VolunteerAssignmentRow?> _findById(String id) {
    return (db.select(
      db.volunteerAssignments,
    )..where((assignment) => assignment.id.equals(id))).getSingleOrNull();
  }
}

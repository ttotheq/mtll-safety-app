import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/seeds/clearance_seed_data.dart';
import 'league_scoped_repository.dart';

class RoleClearanceRequirementRepository extends LeagueScopedRepository {
  RoleClearanceRequirementRepository({
    required super.db,
    required super.sessionContext,
  });

  static const allowedRequirements = {
    SeedRequirementLevels.required,
    SeedRequirementLevels.optional,
    SeedRequirementLevels.conditionalOk,
    SeedRequirementLevels.notApplicable,
  };

  Future<List<RoleClearanceRequirementRow>> listAll() {
    return (db.select(db.roleClearanceRequirements)
          ..where((requirement) => tenantFilter(requirement.leagueId))
          ..orderBy([
            (requirement) => OrderingTerm(expression: requirement.roleId),
            (requirement) =>
                OrderingTerm(expression: requirement.clearanceTypeId),
          ]))
        .get();
  }

  Future<RoleClearanceRequirementRow?> getById(String id) async {
    final row = await _findById(id);
    if (row == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'RoleClearanceRequirement',
      entityId: row.id,
      rowLeagueId: row.leagueId,
    );
    return row;
  }

  Future<RoleClearanceRequirementRow> create({
    required String roleId,
    required String clearanceTypeId,
    required String requirement,
    String? seasonId,
    int? minAge,
    String? notes,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'RoleClearanceRequirement',
      operation: 'create',
    );

    final now = currentTimestamp();
    final row = RoleClearanceRequirementRow(
      id: newId(),
      leagueId: sessionContext.leagueId,
      seasonId: normalizeNullable(seasonId),
      roleId: requireNonBlank(roleId, 'roleId'),
      clearanceTypeId: requireNonBlank(clearanceTypeId, 'clearanceTypeId'),
      requirement: _requireRequirementLevel(requirement),
      minAge: minAge,
      notes: normalizeNullable(notes),
      createdAt: now,
      updatedAt: now,
      createdByUserId: sessionContext.userId,
      updatedByUserId: sessionContext.userId,
    );

    await db
        .into(db.roleClearanceRequirements)
        .insert(
          RoleClearanceRequirementsCompanion.insert(
            id: row.id,
            leagueId: row.leagueId,
            seasonId: Value(row.seasonId),
            roleId: row.roleId,
            clearanceTypeId: row.clearanceTypeId,
            requirement: row.requirement,
            minAge: Value(row.minAge),
            notes: Value(row.notes),
            createdAt: Value(row.createdAt),
            updatedAt: Value(row.updatedAt),
            createdByUserId: Value(row.createdByUserId),
            updatedByUserId: Value(row.updatedByUserId),
          ),
        );

    await writeAuditLog(
      entityName: 'RoleClearanceRequirement',
      entityId: row.id,
      action: LeagueScopedRepository.createAction,
      after: row.toJson(),
      at: now,
    );
    return row;
  }

  Future<RoleClearanceRequirementRow?> update({
    required String id,
    required String requirement,
    int? minAge,
    String? notes,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'RoleClearanceRequirement',
      operation: 'update',
      entityId: id,
    );

    final existing = await _findById(id);
    if (existing == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'RoleClearanceRequirement',
      entityId: existing.id,
      rowLeagueId: existing.leagueId,
    );

    final now = currentTimestamp();
    await (db.update(
      db.roleClearanceRequirements,
    )..where((row) => row.id.equals(id) & tenantFilter(row.leagueId))).write(
      RoleClearanceRequirementsCompanion(
        requirement: Value(_requireRequirementLevel(requirement)),
        minAge: Value(minAge),
        notes: Value(normalizeNullable(notes)),
        updatedAt: Value(now),
        updatedByUserId: Value(sessionContext.userId),
      ),
    );

    // Row was just written under the tenant filter above.
    // ignore: cross_tenant_query
    final updated = await (db.select(
      db.roleClearanceRequirements,
    )..where((row) => row.id.equals(id))).getSingle();

    await writeAuditLog(
      entityName: 'RoleClearanceRequirement',
      entityId: id,
      action: LeagueScopedRepository.updateAction,
      before: existing.toJson(),
      after: updated.toJson(),
      at: now,
    );
    return updated;
  }

  String _requireRequirementLevel(String requirement) {
    final normalized = requireNonBlank(requirement, 'requirement');
    if (!allowedRequirements.contains(normalized)) {
      throw ArgumentError.value(
        requirement,
        'requirement',
        'must be one of $allowedRequirements',
      );
    }

    return normalized;
  }

  Future<RoleClearanceRequirementRow?> _findById(String id) {
    // Unfiltered by design: callers run assertLeagueScope on the row
    // so cross-tenant UUID probes are audited before denial.
    // ignore: cross_tenant_query
    return (db.select(
      db.roleClearanceRequirements,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }
}

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'league_scoped_repository.dart';

class RoleRepository extends LeagueScopedRepository {
  RoleRepository({required super.db, required super.sessionContext});

  Future<List<RoleRow>> listAll() {
    return (db.select(db.roles)
          ..where((role) => tenantFilter(role.leagueId))
          ..orderBy([
            (role) => OrderingTerm(expression: role.sortOrder),
            (role) => OrderingTerm(expression: role.name),
          ]))
        .get();
  }

  Future<RoleRow?> getById(String id) async {
    final row = await _findById(id);
    if (row == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'Role',
      entityId: row.id,
      rowLeagueId: row.leagueId,
    );
    return row;
  }

  Future<RoleRow> create({
    required String name,
    required bool isOnField,
    required bool permitsMinor,
    required int sortOrder,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'Role',
      operation: 'create',
    );

    final now = currentTimestamp();
    final row = RoleRow(
      id: newId(),
      leagueId: sessionContext.leagueId,
      name: requireNonBlank(name, 'name'),
      isOnField: isOnField,
      permitsMinor: permitsMinor,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
      createdByUserId: sessionContext.userId,
      updatedByUserId: sessionContext.userId,
    );

    await db
        .into(db.roles)
        .insert(
          RolesCompanion.insert(
            id: row.id,
            leagueId: row.leagueId,
            name: row.name,
            isOnField: row.isOnField,
            permitsMinor: row.permitsMinor,
            sortOrder: row.sortOrder,
            createdAt: Value(row.createdAt),
            updatedAt: Value(row.updatedAt),
            createdByUserId: Value(row.createdByUserId),
            updatedByUserId: Value(row.updatedByUserId),
          ),
        );

    await writeAuditLog(
      entityName: 'Role',
      entityId: row.id,
      action: LeagueScopedRepository.createAction,
      after: row.toJson(),
      at: now,
    );
    return row;
  }

  Future<RoleRow?> update({
    required String id,
    required String name,
    required bool isOnField,
    required bool permitsMinor,
    required int sortOrder,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'Role',
      operation: 'update',
      entityId: id,
    );

    final existing = await _findById(id);
    if (existing == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'Role',
      entityId: existing.id,
      rowLeagueId: existing.leagueId,
    );

    final now = currentTimestamp();
    await (db.update(
      db.roles,
    )..where((role) => role.id.equals(id) & tenantFilter(role.leagueId))).write(
      RolesCompanion(
        name: Value(requireNonBlank(name, 'name')),
        isOnField: Value(isOnField),
        permitsMinor: Value(permitsMinor),
        sortOrder: Value(sortOrder),
        updatedAt: Value(now),
        updatedByUserId: Value(sessionContext.userId),
      ),
    );

    // Row was just written under the tenant filter above.
    // ignore: cross_tenant_query
    final updated = await (db.select(
      db.roles,
    )..where((role) => role.id.equals(id))).getSingle();

    await writeAuditLog(
      entityName: 'Role',
      entityId: id,
      action: LeagueScopedRepository.updateAction,
      before: existing.toJson(),
      after: updated.toJson(),
      at: now,
    );
    return updated;
  }

  Future<RoleRow?> _findById(String id) {
    // Unfiltered by design: callers run assertLeagueScope on the row
    // so cross-tenant UUID probes are audited before denial.
    // ignore: cross_tenant_query
    return (db.select(
      db.roles,
    )..where((role) => role.id.equals(id))).getSingleOrNull();
  }
}

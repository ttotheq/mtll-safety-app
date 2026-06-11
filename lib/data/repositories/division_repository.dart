import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'league_scoped_repository.dart';

class DivisionRepository extends LeagueScopedRepository {
  DivisionRepository({required super.db, required super.sessionContext});

  Future<List<DivisionRow>> listAll() {
    return (db.select(db.divisions)
          ..where((division) => tenantFilter(division.leagueId))
          ..orderBy([
            (division) => OrderingTerm(expression: division.sortOrder),
            (division) => OrderingTerm(expression: division.name),
          ]))
        .get();
  }

  Future<DivisionRow?> getById(String id) async {
    final row = await _findById(id);
    if (row == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'Division',
      entityId: row.id,
      rowLeagueId: row.leagueId,
    );
    return row;
  }

  Future<DivisionRow> create({
    required String name,
    required int sortOrder,
    int? ageMin,
    int? ageMax,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'Division',
      operation: 'create',
    );

    final now = currentTimestamp();
    final row = DivisionRow(
      id: newId(),
      leagueId: sessionContext.leagueId,
      name: requireNonBlank(name, 'name'),
      ageMin: ageMin,
      ageMax: ageMax,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
      createdByUserId: sessionContext.userId,
      updatedByUserId: sessionContext.userId,
    );

    await db
        .into(db.divisions)
        .insert(
          DivisionsCompanion.insert(
            id: row.id,
            leagueId: row.leagueId,
            name: row.name,
            ageMin: Value(row.ageMin),
            ageMax: Value(row.ageMax),
            sortOrder: row.sortOrder,
            createdAt: Value(row.createdAt),
            updatedAt: Value(row.updatedAt),
            createdByUserId: Value(row.createdByUserId),
            updatedByUserId: Value(row.updatedByUserId),
          ),
        );

    await writeAuditLog(
      entityName: 'Division',
      entityId: row.id,
      action: LeagueScopedRepository.createAction,
      after: row.toJson(),
      at: now,
    );
    return row;
  }

  Future<DivisionRow?> update({
    required String id,
    required String name,
    required int sortOrder,
    int? ageMin,
    int? ageMax,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'Division',
      operation: 'update',
      entityId: id,
    );

    final existing = await _findById(id);
    if (existing == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'Division',
      entityId: existing.id,
      rowLeagueId: existing.leagueId,
    );

    final now = currentTimestamp();
    await (db.update(db.divisions)..where(
          (division) =>
              division.id.equals(id) & tenantFilter(division.leagueId),
        ))
        .write(
          DivisionsCompanion(
            name: Value(requireNonBlank(name, 'name')),
            ageMin: Value(ageMin),
            ageMax: Value(ageMax),
            sortOrder: Value(sortOrder),
            updatedAt: Value(now),
            updatedByUserId: Value(sessionContext.userId),
          ),
        );

    // Row was just written under the tenant filter above.
    // ignore: cross_tenant_query
    final updated = await (db.select(
      db.divisions,
    )..where((division) => division.id.equals(id))).getSingle();

    await writeAuditLog(
      entityName: 'Division',
      entityId: id,
      action: LeagueScopedRepository.updateAction,
      before: existing.toJson(),
      after: updated.toJson(),
      at: now,
    );
    return updated;
  }

  Future<DivisionRow?> _findById(String id) {
    // Unfiltered by design: callers run assertLeagueScope on the row
    // so cross-tenant UUID probes are audited before denial.
    // ignore: cross_tenant_query
    return (db.select(
      db.divisions,
    )..where((division) => division.id.equals(id))).getSingleOrNull();
  }
}

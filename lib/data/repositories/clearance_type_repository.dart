import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'league_scoped_repository.dart';

class ClearanceTypeRepository extends LeagueScopedRepository {
  ClearanceTypeRepository({required super.db, required super.sessionContext});

  Future<List<ClearanceTypeRow>> listAll() {
    return (db.select(db.clearanceTypes)
          ..where((clearanceType) => tenantFilter(clearanceType.leagueId))
          ..orderBy([
            (clearanceType) =>
                OrderingTerm(expression: clearanceType.sortOrder),
            (clearanceType) => OrderingTerm(expression: clearanceType.code),
          ]))
        .get();
  }

  Future<ClearanceTypeRow?> getById(String id) async {
    final row = await _findById(id);
    if (row == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'ClearanceType',
      entityId: row.id,
      rowLeagueId: row.leagueId,
    );
    return row;
  }

  Future<ClearanceTypeRow> create({
    required String code,
    required String name,
    required String category,
    required bool isRecurring,
    required bool evidenceRequired,
    required int sortOrder,
    int? defaultValidityMonths,
    String? evidenceFormatHint,
    String? description,
    String? sourceUrl,
    bool active = true,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'ClearanceType',
      operation: 'create',
    );

    final now = currentTimestamp();
    final row = ClearanceTypeRow(
      id: newId(),
      leagueId: sessionContext.leagueId,
      code: requireNonBlank(code, 'code'),
      name: requireNonBlank(name, 'name'),
      category: requireNonBlank(category, 'category'),
      isRecurring: isRecurring,
      defaultValidityMonths: defaultValidityMonths,
      evidenceRequired: evidenceRequired,
      evidenceFormatHint: normalizeNullable(evidenceFormatHint),
      description: normalizeNullable(description),
      sourceUrl: normalizeNullable(sourceUrl),
      sortOrder: sortOrder,
      active: active,
      createdAt: now,
      updatedAt: now,
      createdByUserId: sessionContext.userId,
      updatedByUserId: sessionContext.userId,
    );

    await db
        .into(db.clearanceTypes)
        .insert(
          ClearanceTypesCompanion.insert(
            id: row.id,
            leagueId: row.leagueId,
            code: row.code,
            name: row.name,
            category: row.category,
            isRecurring: row.isRecurring,
            defaultValidityMonths: Value(row.defaultValidityMonths),
            evidenceRequired: row.evidenceRequired,
            evidenceFormatHint: Value(row.evidenceFormatHint),
            description: Value(row.description),
            sourceUrl: Value(row.sourceUrl),
            sortOrder: row.sortOrder,
            active: Value(row.active),
            createdAt: Value(row.createdAt),
            updatedAt: Value(row.updatedAt),
            createdByUserId: Value(row.createdByUserId),
            updatedByUserId: Value(row.updatedByUserId),
          ),
        );

    await writeAuditLog(
      entityName: 'ClearanceType',
      entityId: row.id,
      action: LeagueScopedRepository.createAction,
      after: row.toJson(),
      at: now,
    );
    return row;
  }

  Future<ClearanceTypeRow?> update({
    required String id,
    required String code,
    required String name,
    required String category,
    required bool isRecurring,
    required bool evidenceRequired,
    required int sortOrder,
    int? defaultValidityMonths,
    String? evidenceFormatHint,
    String? description,
    String? sourceUrl,
    required bool active,
  }) async {
    await requireRole(
      minimum: UserRole.admin,
      entityName: 'ClearanceType',
      operation: 'update',
      entityId: id,
    );

    final existing = await _findById(id);
    if (existing == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'ClearanceType',
      entityId: existing.id,
      rowLeagueId: existing.leagueId,
    );

    final now = currentTimestamp();
    await (db.update(db.clearanceTypes)..where(
          (clearanceType) =>
              clearanceType.id.equals(id) &
              tenantFilter(clearanceType.leagueId),
        ))
        .write(
          ClearanceTypesCompanion(
            code: Value(requireNonBlank(code, 'code')),
            name: Value(requireNonBlank(name, 'name')),
            category: Value(requireNonBlank(category, 'category')),
            isRecurring: Value(isRecurring),
            defaultValidityMonths: Value(defaultValidityMonths),
            evidenceRequired: Value(evidenceRequired),
            evidenceFormatHint: Value(normalizeNullable(evidenceFormatHint)),
            description: Value(normalizeNullable(description)),
            sourceUrl: Value(normalizeNullable(sourceUrl)),
            sortOrder: Value(sortOrder),
            active: Value(active),
            updatedAt: Value(now),
            updatedByUserId: Value(sessionContext.userId),
          ),
        );

    final updated = await (db.select(
      db.clearanceTypes,
    )..where((clearanceType) => clearanceType.id.equals(id))).getSingle();

    await writeAuditLog(
      entityName: 'ClearanceType',
      entityId: id,
      action: LeagueScopedRepository.updateAction,
      before: existing.toJson(),
      after: updated.toJson(),
      at: now,
    );
    return updated;
  }

  Future<ClearanceTypeRow?> _findById(String id) {
    return (db.select(
      db.clearanceTypes,
    )..where((clearanceType) => clearanceType.id.equals(id))).getSingleOrNull();
  }
}

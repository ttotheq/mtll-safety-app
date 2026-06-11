import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'session_context.dart';

export 'session_context.dart' show AuthorizationException, UserRole;

abstract class LeagueScopedRepository {
  LeagueScopedRepository({
    required this.db,
    required this.sessionContext,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  static const createAction = 'CREATE';
  static const updateAction = 'UPDATE';
  static const crossTenantAccessAttemptAction = 'CROSS_TENANT_ACCESS_ATTEMPT';
  static const authorizationDeniedAction = 'AUTHZ_DENIED';

  final AppDatabase db;
  final SessionContext sessionContext;
  final Uuid _uuid;

  Expression<bool> tenantFilter(GeneratedColumn<String> column) =>
      column.equals(sessionContext.leagueId);

  String newId() => _uuid.v7();

  DateTime currentTimestamp() => DateTime.now().toUtc();

  String requireNonBlank(String value, String parameterName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, parameterName, 'must not be blank');
    }

    return trimmed;
  }

  String? normalizeNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  Future<void> writeAuditLog({
    required String entityName,
    required String entityId,
    required String action,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    DateTime? at,
  }) {
    return db
        .into(db.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            id: newId(),
            leagueId: sessionContext.leagueId,
            userId: Value(sessionContext.userId),
            at: at ?? currentTimestamp(),
            entity: entityName,
            entityId: entityId,
            action: action,
            beforeJson: before == null
                ? const Value.absent()
                : Value(jsonEncode(before)),
            afterJson: after == null
                ? const Value.absent()
                : Value(jsonEncode(after)),
          ),
        );
  }

  // EXECUTION-PLAN §6.6.2 — role enforcement at the repository layer.
  // The UI may hide buttons; the repository is authoritative. Named
  // `_requireRole` in the plan; exposed without the underscore so subclass
  // repositories in other libraries can call it.
  Future<void> requireRole({
    required UserRole minimum,
    required String entityName,
    required String operation,
    String? entityId,
  }) async {
    if (sessionContext.role.atLeast(minimum)) {
      return;
    }

    await writeAuditLog(
      entityName: entityName,
      entityId: entityId ?? 'N/A',
      action: authorizationDeniedAction,
      after: {
        'operation': operation,
        'requiredRole': minimum.wireName,
        'sessionRole': sessionContext.role.wireName,
      },
    );

    throw AuthorizationException(
      '$operation on $entityName requires ${minimum.wireName}; '
      'session role is ${sessionContext.role.wireName}',
    );
  }

  Future<void> assertLeagueScope({
    required String entityName,
    required String entityId,
    required String rowLeagueId,
  }) async {
    if (rowLeagueId == sessionContext.leagueId) {
      return;
    }

    await writeAuditLog(
      entityName: entityName,
      entityId: entityId,
      action: crossTenantAccessAttemptAction,
      after: {
        'sessionLeagueId': sessionContext.leagueId,
        'rowLeagueId': rowLeagueId,
      },
    );

    throw AssertionError(
      'Cross-tenant access denied for $entityName($entityId): '
      'session league ${sessionContext.leagueId}, row league $rowLeagueId',
    );
  }
}

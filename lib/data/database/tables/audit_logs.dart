import 'package:drift/drift.dart';

// PRD §7.15 / design-notes §1.15 — AuditLog.
// This table is append-only at the DB layer; see AppDatabase trigger DDL.
@DataClassName('AuditLogRow')
class AuditLogs extends Table {
  @override
  String get tableName => 'audit_log';

  TextColumn get id => text()();
  TextColumn get leagueId => text()();
  TextColumn get userId => text().nullable()();

  DateTimeColumn get at => dateTime()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
  TextColumn get ip => text().nullable()();
  TextColumn get userAgent => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

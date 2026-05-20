import 'package:drift/drift.dart';

// EXECUTION-PLAN §6.2.3 — AuditLogChain.
@DataClassName('AuditLogChainRow')
class AuditLogChains extends Table {
  @override
  String get tableName => 'audit_log_chain';

  TextColumn get id => text()();
  DateTimeColumn get chainDate => dateTime()();
  IntColumn get rowCount => integer()();
  TextColumn get dayHash => text()();
  TextColumn get prevHash => text().nullable()();
  TextColumn get chainHash => text()();
  DateTimeColumn get sealedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {chainDate},
  ];
}

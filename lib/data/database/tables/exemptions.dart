import 'package:drift/drift.dart';

// PRD §7.11 / design-notes §1.11 — Exemption.
// league_id is duplicated for direct tenant filtering in repositories.
@DataClassName('ExemptionRow')
class Exemptions extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get volunteerClearanceId => text()();
  TextColumn get reason => text()();
  TextColumn get grantingAuthority => text()();
  TextColumn get grantedByName => text().nullable()();
  TextColumn get grantedByUserId => text().nullable()();
  DateTimeColumn get grantedOn => dateTime()();
  DateTimeColumn get expiresOn => dateTime().nullable()();
  TextColumn get evidenceFileId => text().nullable()();
  DateTimeColumn get revokedAt => dateTime().nullable()();
  TextColumn get revokedReason => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {volunteerClearanceId},
  ];
}

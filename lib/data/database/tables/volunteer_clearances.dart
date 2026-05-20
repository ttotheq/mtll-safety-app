import 'package:drift/drift.dart';

// PRD §7.10 / design-notes §1.10 — VolunteerClearance.
// league_id is duplicated for direct tenant filtering in repositories.
@DataClassName('VolunteerClearanceRow')
class VolunteerClearances extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get volunteerId => text()();
  TextColumn get clearanceTypeId => text()();
  TextColumn get seasonId => text().nullable()();
  TextColumn get status => text()();
  DateTimeColumn get completedOn => dateTime().nullable()();
  DateTimeColumn get expiresOn => dateTime().nullable()();
  TextColumn get verifiedByUserId => text().nullable()();
  DateTimeColumn get verifiedAt => dateTime().nullable()();
  TextColumn get evidenceFileId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get source => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

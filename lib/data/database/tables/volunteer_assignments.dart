import 'package:drift/drift.dart';

// PRD §7.7 / design-notes §1.7 — VolunteerAssignment.
// league_id is carried explicitly per EXECUTION-PLAN §2.4 / §6.3.1 so
// LeagueScopedRepository can tenant-filter assignments without joins.
@DataClassName('VolunteerAssignmentRow')
class VolunteerAssignments extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get volunteerId => text()();
  TextColumn get teamId => text().nullable()();
  TextColumn get seasonId => text()();
  TextColumn get roleId => text()();

  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get status => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

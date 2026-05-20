import 'package:drift/drift.dart';

// PRD §7.13 / design-notes §1.13 — ActivityLog.
@DataClassName('ActivityLogRow')
class ActivityLogs extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();
  TextColumn get volunteerId => text()();
  TextColumn get actorUserId => text()();

  TextColumn get kind => text()();
  TextColumn get body => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get relatedClearanceId => text().nullable()();
  TextColumn get importSource => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

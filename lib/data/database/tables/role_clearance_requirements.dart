import 'package:drift/drift.dart';

// PRD §7.9 / design-notes §1.9 — RoleClearanceRequirement.
@DataClassName('RoleClearanceRequirementRow')
class RoleClearanceRequirements extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get seasonId => text().nullable()();
  TextColumn get roleId => text()();
  TextColumn get clearanceTypeId => text()();
  TextColumn get requirement => text()();
  IntColumn get minAge => integer().nullable()();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

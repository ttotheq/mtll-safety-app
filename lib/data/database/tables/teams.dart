import 'package:drift/drift.dart';

// PRD §7.4 / design-notes §1.4 — Team.
// league_id is duplicated from Season/Division per EXECUTION-PLAN §2.4 /
// §6.3.1 so every league-scoped entity can be tenant-filtered directly.
// display_name ("MAJORS - BONILLA") is denormalized and computed on write
// at the repository layer — workbook-compatible label.
// manager_volunteer_id stores Volunteer.id when a manager is assigned.
@DataClassName('TeamRow')
class Teams extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();
  TextColumn get seasonId => text()();
  TextColumn get divisionId => text()();

  TextColumn get name => text()();
  TextColumn get displayName => text()();
  TextColumn get managerVolunteerId => text().nullable()();
  TextColumn get color => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // (season_id, division_id, name) unique per design-notes §1.4.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {seasonId, divisionId, name},
  ];
}

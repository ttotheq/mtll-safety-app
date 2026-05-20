import 'package:drift/drift.dart';

// PRD §7.6 / design-notes §1.6 — Role.
@DataClassName('RoleRow')
class Roles extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get name => text()();
  BoolColumn get isOnField => boolean()();
  BoolColumn get permitsMinor => boolean()();
  IntColumn get sortOrder => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // (league_id, name) unique per PRD §7.6 / design-notes §1.6.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {leagueId, name},
  ];
}

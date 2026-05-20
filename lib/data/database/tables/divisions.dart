import 'package:drift/drift.dart';

// PRD §7.3 / design-notes §1.3 — Division.
@DataClassName('DivisionRow')
class Divisions extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get name => text()();
  IntColumn get ageMin => integer().nullable()();
  IntColumn get ageMax => integer().nullable()();
  IntColumn get sortOrder => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // (league_id, name) unique per design-notes §1.3.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {leagueId, name},
  ];
}

import 'package:drift/drift.dart';

// PRD §7.2 / design-notes §1.2 — Season.
// term is a TEXT enum: Spring / Fall / Summer / AllStars / Winter.
// Validated at the domain layer; SQLite has no native enum.
@DataClassName('SeasonRow')
class Seasons extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get name => text()();
  IntColumn get year => integer()();
  TextColumn get term => text()();

  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();

  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // (league_id, year, term) unique per design-notes §1.2.
  // Partial-unique (league_id) where is_active=true is created via raw DDL
  // in AppDatabase.onCreate — SQLite supports it, Drift's uniqueKeys getter
  // does not express WHERE predicates.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {leagueId, year, term},
  ];
}

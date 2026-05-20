import 'package:drift/drift.dart';

// PRD §7.1 / design-notes §1.1 — League. Multi-tenant root.
// UUIDv7 PK stored as TEXT. Conversion to UuidValue happens at the
// repository boundary, not the schema layer.
@DataClassName('LeagueRow')
class Leagues extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();
  TextColumn get shortName => text().nullable()();
  TextColumn get district => text().nullable()();
  TextColumn get charterNumber => text().nullable()();

  TextColumn get timezone =>
      text().withDefault(const Constant('America/Los_Angeles'))();

  TextColumn get contactName => text().nullable()();
  TextColumn get contactEmail => text().nullable()();
  TextColumn get contactPhone => text().nullable()();

  TextColumn get logoBlobId => text().nullable()();
  TextColumn get primaryColorHex => text().nullable()();

  TextColumn get locale => text().withDefault(const Constant('en-US'))();
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

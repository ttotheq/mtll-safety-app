import 'package:drift/drift.dart';

// PRD §7.8 / design-notes §1.8 — ClearanceType.
@DataClassName('ClearanceTypeRow')
class ClearanceTypes extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  BoolColumn get isRecurring => boolean()();
  IntColumn get defaultValidityMonths => integer().nullable()();
  BoolColumn get evidenceRequired => boolean()();
  TextColumn get evidenceFormatHint => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  IntColumn get sortOrder => integer()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // (league_id, code) unique per PRD §7.8 / design-notes §1.8.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {leagueId, code},
  ];
}

import 'package:drift/drift.dart';

// PRD §7.5 / design-notes §1.5 — Volunteer.
// email and phone are normalized at the repository boundary.
// is_junior caches the DOB-derived minor check for query speed.
@DataClassName('VolunteerRow')
class Volunteers extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get preferredName => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phoneE164 => text().nullable()();
  DateTimeColumn get dob => dateTime().nullable()();
  TextColumn get addressJson => text().nullable()();

  BoolColumn get isFirstTime => boolean().withDefault(const Constant(false))();
  BoolColumn get followUpFlag => boolean().withDefault(const Constant(false))();
  BoolColumn get isJunior => boolean().withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();
  TextColumn get externalPmId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

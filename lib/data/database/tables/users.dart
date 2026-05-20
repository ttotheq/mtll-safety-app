import 'package:drift/drift.dart';

// PRD §7.14 / design-notes §1.14 — User.
@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();

  TextColumn get email => text()();
  TextColumn get name => text()();
  TextColumn get role => text()();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get localPasscodeHash => text().nullable()();
  TextColumn get authProvider => text()();
  DateTimeColumn get disabledAt => dateTime().nullable()();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

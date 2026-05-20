import 'package:drift/drift.dart';

// PRD §7.12 / design-notes §1.12 — EvidenceFile.
// storage_uri is nullable because retention purge deletes the encrypted blob
// from disk but preserves the row as evidence that the file once existed.
@DataClassName('EvidenceFileRow')
class EvidenceFiles extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();
  TextColumn get volunteerId => text()();

  TextColumn get filenameOriginal => text()();
  TextColumn get mime => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get sha256 => text()();
  TextColumn get storageUri => text().nullable()();

  TextColumn get encryptionKdf => text()();
  BlobColumn get fileEncryptionNonce => blob()();
  BlobColumn get keyWrapNonce => blob()();
  BlobColumn get wrappedFileKey => blob()();

  DateTimeColumn get uploadedAt => dateTime()();
  TextColumn get uploadedByUserId => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

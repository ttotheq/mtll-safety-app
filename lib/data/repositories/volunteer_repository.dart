import '../database/app_database.dart';
import 'league_scoped_repository.dart';

class VolunteerRepository extends LeagueScopedRepository {
  VolunteerRepository({required super.db, required super.sessionContext});

  Future<List<VolunteerRow>> listAll() {
    return (db.select(
      db.volunteers,
    )..where((volunteer) => tenantFilter(volunteer.leagueId))).get();
  }

  Future<VolunteerRow?> getById(String id) async {
    // Fetch by ID first so cross-tenant UUID probes are audited before denial.
    // ignore: cross_tenant_query
    final row = await (db.select(
      db.volunteers,
    )..where((volunteer) => volunteer.id.equals(id))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    await assertLeagueScope(
      entityName: 'Volunteer',
      entityId: row.id,
      rowLeagueId: row.leagueId,
    );
    return row;
  }
}

// Synthetic-violation fixture for the cross_tenant_query custom lint
// (EXECUTION-PLAN §6.3.5; S1 exit criterion "cross-tenant lint fires on a
// synthetic violation"). `dart run custom_lint` fails if the expect_lint
// marker stops matching a reported lint, and fails on any unexpected lint
// against the compliant query below.
//
// This file is a lint fixture, not a test — it is never executed.
import 'package:mtll_safety_app/data/database/app_database.dart';

Future<List<TeamRow>> syntheticCrossTenantViolation(AppDatabase db) {
  // expect_lint: cross_tenant_query
  return db.select(db.teams).get();
}

Future<List<TeamRow>> compliantTenantScopedQuery(
  AppDatabase db,
  String leagueId,
) {
  return (db.select(
    db.teams,
  )..where((team) => team.leagueId.equals(leagueId))).get();
}

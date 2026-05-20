import 'clearance_seed_data.dart';

class RoleSeed {
  const RoleSeed({
    required this.name,
    required this.isOnField,
    required this.permitsMinor,
    required this.sortOrder,
  });

  final String name;
  final bool isOnField;
  final bool permitsMinor;
  final int sortOrder;
}

// Current onboarding seed follows EXECUTION-PLAN W1/S2: nine roles, excluding
// Junior Scorekeeper until the spec conflict is reconciled.
const defaultRoleSeeds = <RoleSeed>[
  RoleSeed(
    name: SeedRoleNames.manager,
    isOnField: true,
    permitsMinor: false,
    sortOrder: 10,
  ),
  RoleSeed(
    name: SeedRoleNames.rosteredCoach,
    isOnField: true,
    permitsMinor: false,
    sortOrder: 20,
  ),
  RoleSeed(
    name: SeedRoleNames.assistantCoachOnField,
    isOnField: true,
    permitsMinor: false,
    sortOrder: 30,
  ),
  RoleSeed(
    name: SeedRoleNames.assistantCoachDugout,
    isOnField: false,
    permitsMinor: false,
    sortOrder: 40,
  ),
  RoleSeed(
    name: SeedRoleNames.teamParent,
    isOnField: false,
    permitsMinor: false,
    sortOrder: 50,
  ),
  RoleSeed(
    name: SeedRoleNames.scorekeeper,
    isOnField: false,
    permitsMinor: false,
    sortOrder: 60,
  ),
  RoleSeed(
    name: SeedRoleNames.umpire,
    isOnField: true,
    permitsMinor: false,
    sortOrder: 70,
  ),
  RoleSeed(
    name: SeedRoleNames.juniorUmpire,
    isOnField: true,
    permitsMinor: true,
    sortOrder: 80,
  ),
  RoleSeed(
    name: SeedRoleNames.notAssigned,
    isOnField: false,
    permitsMinor: false,
    sortOrder: 90,
  ),
];

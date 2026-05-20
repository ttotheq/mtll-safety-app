// Locked seed data for Sprint 1 ticket #3 and W1 onboarding.
// Source of truth: EXECUTION-PLAN §2.2, §2.6, and PRD §15 Appendix A.

class ClearanceTypeSeed {
  const ClearanceTypeSeed({
    required this.code,
    required this.name,
    required this.category,
    required this.isRecurring,
    required this.defaultValidityMonths,
    required this.evidenceRequired,
    required this.sortOrder,
    required this.active,
    this.evidenceFormatHint,
    this.description,
  });

  final String code;
  final String name;
  final String category;
  final bool isRecurring;
  final int? defaultValidityMonths;
  final bool evidenceRequired;
  final int sortOrder;
  final bool active;
  final String? evidenceFormatHint;
  final String? description;
}

class RoleClearanceRequirementSeed {
  const RoleClearanceRequirementSeed({
    required this.roleName,
    required this.clearanceCode,
    required this.requirement,
    this.minAge,
    this.notes,
  });

  final String roleName;
  final String clearanceCode;
  final String requirement;
  final int? minAge;
  final String? notes;
}

abstract final class SeedClearanceCategories {
  static const annual = 'ANNUAL';
  static const newSeason = 'NEW_SEASON';
  static const oneTime = 'ONE_TIME';
  static const clinic = 'CLINIC';
  static const seasonSpecific = 'SEASON_SPECIFIC';
}

abstract final class SeedRequirementLevels {
  static const required = 'REQUIRED';
  static const optional = 'OPTIONAL';
  static const conditionalOk = 'CONDITIONAL_OK';
  static const notApplicable = 'NOT_APPLICABLE';
}

abstract final class SeedRoleNames {
  static const manager = 'Manager';
  static const rosteredCoach = 'Rostered Coach';
  static const assistantCoachOnField = 'Assistant Coach (On-Field)';
  static const assistantCoachDugout = 'Assistant Coach (Dugout)';
  static const teamParent = 'Team Parent';
  static const scorekeeper = 'Scorekeeper';
  static const umpire = 'Umpire';
  static const juniorUmpire = 'Junior Umpire';
  static const notAssigned = 'Not Assigned';

  static const matrixRoles = <String>[
    manager,
    rosteredCoach,
    assistantCoachOnField,
    assistantCoachDugout,
    teamParent,
    scorekeeper,
    umpire,
    juniorUmpire,
  ];
}

abstract final class SeedClearanceCodes {
  static const backgroundCheck = 'BACKGROUND_CHECK';
  static const livescan = 'LIVESCAN';
  static const abuseNeglect = 'ABUSE_NEGLECT';
  static const firstAid = 'FIRST_AID';
  static const safetyTraining = 'SAFETY_TRAINING';
  static const concussion = 'CONCUSSION';
  static const sca = 'SCA';
  static const diamondLeader = 'DIAMOND_LEADER';
  static const skillsClinic = 'SKILLS_CLINIC';
  static const safetyClinic = 'SAFETY_CLINIC';
  static const fundamentals2026 = 'FUNDAMENTALS_2026';
  static const safety2026 = 'SAFETY_2026';
}

// All expiring/per-season categories are treated as recurring; ONE_TIME is the
// only non-recurring category in the seed catalog.
const defaultClearanceTypeSeeds = <ClearanceTypeSeed>[
  ClearanceTypeSeed(
    code: SeedClearanceCodes.backgroundCheck,
    name: 'Background Check',
    category: SeedClearanceCategories.annual,
    isRecurring: true,
    defaultValidityMonths: 12,
    evidenceRequired: true,
    sortOrder: 10,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.livescan,
    name: 'LiveScan',
    category: SeedClearanceCategories.oneTime,
    isRecurring: false,
    defaultValidityMonths: 24,
    evidenceRequired: true,
    sortOrder: 20,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.abuseNeglect,
    name: 'Abuse / Neglect Training',
    category: SeedClearanceCategories.annual,
    isRecurring: true,
    defaultValidityMonths: 12,
    evidenceRequired: true,
    sortOrder: 30,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.firstAid,
    name: 'First Aid',
    category: SeedClearanceCategories.newSeason,
    isRecurring: true,
    defaultValidityMonths: 12,
    evidenceRequired: true,
    sortOrder: 40,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.safetyTraining,
    name: 'Safety Training',
    category: SeedClearanceCategories.newSeason,
    isRecurring: true,
    defaultValidityMonths: 12,
    evidenceRequired: true,
    sortOrder: 50,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.concussion,
    name: 'Concussion Training',
    category: SeedClearanceCategories.oneTime,
    isRecurring: false,
    defaultValidityMonths: null,
    evidenceRequired: true,
    sortOrder: 60,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.sca,
    name: 'Sudden Cardiac Arrest Awareness',
    category: SeedClearanceCategories.oneTime,
    isRecurring: false,
    defaultValidityMonths: null,
    evidenceRequired: true,
    sortOrder: 70,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.diamondLeader,
    name: 'Diamond Leader',
    category: SeedClearanceCategories.oneTime,
    isRecurring: false,
    defaultValidityMonths: null,
    evidenceRequired: true,
    sortOrder: 80,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.skillsClinic,
    name: 'Skills Clinic',
    category: SeedClearanceCategories.clinic,
    isRecurring: true,
    defaultValidityMonths: null,
    evidenceRequired: false,
    sortOrder: 90,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.safetyClinic,
    name: 'Safety Clinic',
    category: SeedClearanceCategories.clinic,
    isRecurring: true,
    defaultValidityMonths: null,
    evidenceRequired: false,
    sortOrder: 100,
    active: true,
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.fundamentals2026,
    name: '2026 Fundamentals',
    category: SeedClearanceCategories.seasonSpecific,
    isRecurring: true,
    defaultValidityMonths: null,
    evidenceRequired: true,
    sortOrder: 110,
    active: false,
    description: 'Deferred to 2027 season per locked 2026-05-19 decision.',
  ),
  ClearanceTypeSeed(
    code: SeedClearanceCodes.safety2026,
    name: '2026 Safety',
    category: SeedClearanceCategories.seasonSpecific,
    isRecurring: true,
    defaultValidityMonths: null,
    evidenceRequired: true,
    sortOrder: 120,
    active: true,
  ),
];

final defaultRoleClearanceRequirementSeeds = _buildDefaultMatrix();

List<RoleClearanceRequirementSeed> _buildDefaultMatrix() {
  return [
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.backgroundCheck,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(minAge: 18),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.livescan,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(minAge: 18),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.abuseNeglect,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.optional(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.concussion,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.optional(),
        _MatrixCell.notApplicable(),
        _MatrixCell.required(minAge: 18),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.sca,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.optional(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.diamondLeader,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.optional(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.firstAid,
      cells: const [
        _MatrixCell.conditionalOk(),
        _MatrixCell.conditionalOk(),
        _MatrixCell.optional(),
        _MatrixCell.optional(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.safetyTraining,
      cells: const [
        _MatrixCell.conditionalOk(),
        _MatrixCell.conditionalOk(),
        _MatrixCell.optional(),
        _MatrixCell.optional(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.skillsClinic,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.conditionalOk(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.optional(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.safetyClinic,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.conditionalOk(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.optional(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.fundamentals2026,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
      ],
    ),
    ..._expandMatrixRow(
      clearanceCode: SeedClearanceCodes.safety2026,
      cells: const [
        _MatrixCell.required(),
        _MatrixCell.required(),
        _MatrixCell.optional(),
        _MatrixCell.optional(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
        _MatrixCell.notApplicable(),
      ],
    ),
  ];
}

List<RoleClearanceRequirementSeed> _expandMatrixRow({
  required String clearanceCode,
  required List<_MatrixCell> cells,
}) {
  return [
    for (var i = 0; i < SeedRoleNames.matrixRoles.length; i++)
      RoleClearanceRequirementSeed(
        roleName: SeedRoleNames.matrixRoles[i],
        clearanceCode: clearanceCode,
        requirement: cells[i].requirement,
        minAge: cells[i].minAge,
      ),
  ];
}

class _MatrixCell {
  const _MatrixCell.required({this.minAge})
    : requirement = SeedRequirementLevels.required;

  const _MatrixCell.optional()
    : requirement = SeedRequirementLevels.optional,
      minAge = null;

  const _MatrixCell.conditionalOk()
    : requirement = SeedRequirementLevels.conditionalOk,
      minAge = null;

  const _MatrixCell.notApplicable()
    : requirement = SeedRequirementLevels.notApplicable,
      minAge = null;

  final String requirement;
  final int? minAge;
}

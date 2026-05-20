import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/seeds/clearance_seed_data.dart';
import '../database/seeds/role_seed_data.dart';

class OnboardingDivisionInput {
  const OnboardingDivisionInput({
    required this.name,
    required this.sortOrder,
    this.ageMin,
    this.ageMax,
  });

  final String name;
  final int sortOrder;
  final int? ageMin;
  final int? ageMax;
}

class LeagueOnboardingResult {
  const LeagueOnboardingResult({
    required this.leagueId,
    required this.ownerUserId,
    required this.divisionCount,
    required this.roleCount,
    required this.clearanceTypeCount,
    required this.requirementCount,
  });

  final String leagueId;
  final String ownerUserId;
  final int divisionCount;
  final int roleCount;
  final int clearanceTypeCount;
  final int requirementCount;
}

class LeagueOnboardingRepository {
  LeagueOnboardingRepository({required this.db, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const createAction = 'CREATE';
  static const ownerRole = 'OWNER';
  static const localPinAuthProvider = 'LOCAL_PIN';

  final AppDatabase db;
  final Uuid _uuid;

  Future<LeagueOnboardingResult> bootstrapLeague({
    required String leagueName,
    required Iterable<OnboardingDivisionInput> divisions,
    required String ownerEmail,
    required String ownerName,
    required String ownerPasscodeHash,
    String? shortName,
    String? district,
    String? charterNumber,
  }) async {
    _requireNonBlank(leagueName, 'leagueName');
    _requireNonBlank(ownerEmail, 'ownerEmail');
    _requireNonBlank(ownerName, 'ownerName');
    _requireNonBlank(ownerPasscodeHash, 'ownerPasscodeHash');

    final normalizedDivisions = _normalizeDivisions(divisions);
    if (normalizedDivisions.isEmpty) {
      throw ArgumentError.value(
        divisions,
        'divisions',
        'At least one division is required for onboarding.',
      );
    }

    final now = DateTime.now().toUtc();
    final leagueId = _uuid.v7();
    final ownerUserId = _uuid.v7();

    return db.transaction(() async {
      final league = LeagueRow(
        id: leagueId,
        name: leagueName.trim(),
        shortName: _normalizeNullable(shortName),
        district: _normalizeNullable(district),
        charterNumber: _normalizeNullable(charterNumber),
        timezone: 'America/Los_Angeles',
        contactName: null,
        contactEmail: null,
        contactPhone: null,
        logoBlobId: null,
        primaryColorHex: null,
        locale: 'en-US',
        settingsJson: '{}',
        createdAt: now,
        updatedAt: now,
        createdByUserId: ownerUserId,
        updatedByUserId: ownerUserId,
      );
      await db.into(db.leagues).insert(_leagueCompanion(league));
      await _writeAuditLog(
        leagueId: leagueId,
        userId: ownerUserId,
        entity: 'League',
        entityId: league.id,
        after: league.toJson(),
        at: now,
      );

      for (final divisionInput in normalizedDivisions) {
        final division = DivisionRow(
          id: _uuid.v7(),
          leagueId: leagueId,
          name: divisionInput.name,
          ageMin: divisionInput.ageMin,
          ageMax: divisionInput.ageMax,
          sortOrder: divisionInput.sortOrder,
          createdAt: now,
          updatedAt: now,
          createdByUserId: ownerUserId,
          updatedByUserId: ownerUserId,
        );
        await db.into(db.divisions).insert(_divisionCompanion(division));
        await _writeAuditLog(
          leagueId: leagueId,
          userId: ownerUserId,
          entity: 'Division',
          entityId: division.id,
          after: division.toJson(),
          at: now,
        );
      }

      final roleIdsByName = <String, String>{};
      for (final seed in defaultRoleSeeds) {
        final role = RoleRow(
          id: _uuid.v7(),
          leagueId: leagueId,
          name: seed.name,
          isOnField: seed.isOnField,
          permitsMinor: seed.permitsMinor,
          sortOrder: seed.sortOrder,
          createdAt: now,
          updatedAt: now,
          createdByUserId: ownerUserId,
          updatedByUserId: ownerUserId,
        );
        roleIdsByName[role.name] = role.id;
        await db.into(db.roles).insert(_roleCompanion(role));
        await _writeAuditLog(
          leagueId: leagueId,
          userId: ownerUserId,
          entity: 'Role',
          entityId: role.id,
          after: role.toJson(),
          at: now,
        );
      }

      final clearanceTypeIdsByCode = <String, String>{};
      for (final seed in defaultClearanceTypeSeeds) {
        final clearanceType = ClearanceTypeRow(
          id: _uuid.v7(),
          leagueId: leagueId,
          code: seed.code,
          name: seed.name,
          category: seed.category,
          isRecurring: seed.isRecurring,
          defaultValidityMonths: seed.defaultValidityMonths,
          evidenceRequired: seed.evidenceRequired,
          evidenceFormatHint: seed.evidenceFormatHint,
          description: seed.description,
          sourceUrl: null,
          sortOrder: seed.sortOrder,
          active: seed.active,
          createdAt: now,
          updatedAt: now,
          createdByUserId: ownerUserId,
          updatedByUserId: ownerUserId,
        );
        clearanceTypeIdsByCode[clearanceType.code] = clearanceType.id;
        await db
            .into(db.clearanceTypes)
            .insert(_clearanceTypeCompanion(clearanceType));
        await _writeAuditLog(
          leagueId: leagueId,
          userId: ownerUserId,
          entity: 'ClearanceType',
          entityId: clearanceType.id,
          after: clearanceType.toJson(),
          at: now,
        );
      }

      for (final seed in defaultRoleClearanceRequirementSeeds) {
        final roleId = roleIdsByName[seed.roleName];
        final clearanceTypeId = clearanceTypeIdsByCode[seed.clearanceCode];
        if (roleId == null || clearanceTypeId == null) {
          throw StateError(
            'Default requirement seed references an unknown role or '
            'clearance: ${seed.roleName} / ${seed.clearanceCode}',
          );
        }

        final requirement = RoleClearanceRequirementRow(
          id: _uuid.v7(),
          leagueId: leagueId,
          seasonId: null,
          roleId: roleId,
          clearanceTypeId: clearanceTypeId,
          requirement: seed.requirement,
          minAge: seed.minAge,
          notes: seed.notes,
          createdAt: now,
          updatedAt: now,
          createdByUserId: ownerUserId,
          updatedByUserId: ownerUserId,
        );
        await db
            .into(db.roleClearanceRequirements)
            .insert(_roleClearanceRequirementCompanion(requirement));
        await _writeAuditLog(
          leagueId: leagueId,
          userId: ownerUserId,
          entity: 'RoleClearanceRequirement',
          entityId: requirement.id,
          after: requirement.toJson(),
          at: now,
        );
      }

      final ownerUser = UserRow(
        id: ownerUserId,
        leagueId: leagueId,
        email: ownerEmail.trim(),
        name: ownerName.trim(),
        role: ownerRole,
        passwordHash: null,
        localPasscodeHash: ownerPasscodeHash.trim(),
        authProvider: localPinAuthProvider,
        disabledAt: null,
        lastLoginAt: null,
        createdAt: now,
        updatedAt: now,
        createdByUserId: ownerUserId,
        updatedByUserId: ownerUserId,
      );
      await db.into(db.users).insert(_userCompanion(ownerUser));
      await _writeAuditLog(
        leagueId: leagueId,
        userId: ownerUserId,
        entity: 'User',
        entityId: ownerUser.id,
        after: ownerUser.toJson(),
        at: now,
      );

      return LeagueOnboardingResult(
        leagueId: leagueId,
        ownerUserId: ownerUserId,
        divisionCount: normalizedDivisions.length,
        roleCount: defaultRoleSeeds.length,
        clearanceTypeCount: defaultClearanceTypeSeeds.length,
        requirementCount: defaultRoleClearanceRequirementSeeds.length,
      );
    });
  }

  List<OnboardingDivisionInput> _normalizeDivisions(
    Iterable<OnboardingDivisionInput> divisions,
  ) {
    final normalized = <OnboardingDivisionInput>[];
    final seen = <String>{};

    for (final division in divisions) {
      final name = division.name.trim();
      if (name.isEmpty) {
        continue;
      }

      final dedupeKey = name.toLowerCase();
      if (!seen.add(dedupeKey)) {
        continue;
      }

      normalized.add(
        OnboardingDivisionInput(
          name: name,
          sortOrder: division.sortOrder,
          ageMin: division.ageMin,
          ageMax: division.ageMax,
        ),
      );
    }

    normalized.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return normalized;
  }

  Future<void> _writeAuditLog({
    required String leagueId,
    required String? userId,
    required String entity,
    required String entityId,
    required Map<String, dynamic> after,
    required DateTime at,
  }) {
    return db
        .into(db.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            id: _uuid.v7(),
            leagueId: leagueId,
            userId: Value(userId),
            at: at,
            entity: entity,
            entityId: entityId,
            action: createAction,
            afterJson: Value(jsonEncode(_sanitizeAuditPayload(entity, after))),
          ),
        );
  }
}

LeaguesCompanion _leagueCompanion(LeagueRow league) {
  return LeaguesCompanion(
    id: Value(league.id),
    name: Value(league.name),
    shortName: Value(league.shortName),
    district: Value(league.district),
    charterNumber: Value(league.charterNumber),
    timezone: Value(league.timezone),
    contactName: const Value.absent(),
    contactEmail: const Value.absent(),
    contactPhone: const Value.absent(),
    logoBlobId: const Value.absent(),
    primaryColorHex: const Value.absent(),
    locale: Value(league.locale),
    settingsJson: Value(league.settingsJson),
    createdAt: Value(league.createdAt),
    updatedAt: Value(league.updatedAt),
    createdByUserId: Value(league.createdByUserId),
    updatedByUserId: Value(league.updatedByUserId),
  );
}

DivisionsCompanion _divisionCompanion(DivisionRow division) {
  return DivisionsCompanion(
    id: Value(division.id),
    leagueId: Value(division.leagueId),
    name: Value(division.name),
    ageMin: Value(division.ageMin),
    ageMax: Value(division.ageMax),
    sortOrder: Value(division.sortOrder),
    createdAt: Value(division.createdAt),
    updatedAt: Value(division.updatedAt),
    createdByUserId: Value(division.createdByUserId),
    updatedByUserId: Value(division.updatedByUserId),
  );
}

RolesCompanion _roleCompanion(RoleRow role) {
  return RolesCompanion(
    id: Value(role.id),
    leagueId: Value(role.leagueId),
    name: Value(role.name),
    isOnField: Value(role.isOnField),
    permitsMinor: Value(role.permitsMinor),
    sortOrder: Value(role.sortOrder),
    createdAt: Value(role.createdAt),
    updatedAt: Value(role.updatedAt),
    createdByUserId: Value(role.createdByUserId),
    updatedByUserId: Value(role.updatedByUserId),
  );
}

ClearanceTypesCompanion _clearanceTypeCompanion(
  ClearanceTypeRow clearanceType,
) {
  return ClearanceTypesCompanion(
    id: Value(clearanceType.id),
    leagueId: Value(clearanceType.leagueId),
    code: Value(clearanceType.code),
    name: Value(clearanceType.name),
    category: Value(clearanceType.category),
    isRecurring: Value(clearanceType.isRecurring),
    defaultValidityMonths: Value(clearanceType.defaultValidityMonths),
    evidenceRequired: Value(clearanceType.evidenceRequired),
    evidenceFormatHint: Value(clearanceType.evidenceFormatHint),
    description: Value(clearanceType.description),
    sourceUrl: Value(clearanceType.sourceUrl),
    sortOrder: Value(clearanceType.sortOrder),
    active: Value(clearanceType.active),
    createdAt: Value(clearanceType.createdAt),
    updatedAt: Value(clearanceType.updatedAt),
    createdByUserId: Value(clearanceType.createdByUserId),
    updatedByUserId: Value(clearanceType.updatedByUserId),
  );
}

RoleClearanceRequirementsCompanion _roleClearanceRequirementCompanion(
  RoleClearanceRequirementRow requirement,
) {
  return RoleClearanceRequirementsCompanion(
    id: Value(requirement.id),
    leagueId: Value(requirement.leagueId),
    seasonId: Value(requirement.seasonId),
    roleId: Value(requirement.roleId),
    clearanceTypeId: Value(requirement.clearanceTypeId),
    requirement: Value(requirement.requirement),
    minAge: Value(requirement.minAge),
    notes: Value(requirement.notes),
    createdAt: Value(requirement.createdAt),
    updatedAt: Value(requirement.updatedAt),
    createdByUserId: Value(requirement.createdByUserId),
    updatedByUserId: Value(requirement.updatedByUserId),
  );
}

UsersCompanion _userCompanion(UserRow user) {
  return UsersCompanion(
    id: Value(user.id),
    leagueId: Value(user.leagueId),
    email: Value(user.email),
    name: Value(user.name),
    role: Value(user.role),
    passwordHash: Value(user.passwordHash),
    localPasscodeHash: Value(user.localPasscodeHash),
    authProvider: Value(user.authProvider),
    disabledAt: Value(user.disabledAt),
    lastLoginAt: Value(user.lastLoginAt),
    createdAt: Value(user.createdAt),
    updatedAt: Value(user.updatedAt),
    createdByUserId: Value(user.createdByUserId),
    updatedByUserId: Value(user.updatedByUserId),
  );
}

String? _normalizeNullable(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return trimmed;
}

void _requireNonBlank(String value, String parameterName) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, parameterName, 'must not be blank');
  }
}

Map<String, dynamic> _sanitizeAuditPayload(
  String entity,
  Map<String, dynamic> payload,
) {
  final sanitized = Map<String, dynamic>.from(payload);
  if (entity == 'User') {
    sanitized.remove('passwordHash');
    sanitized.remove('localPasscodeHash');
  }

  return sanitized;
}

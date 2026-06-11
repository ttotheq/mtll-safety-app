// EXECUTION-PLAN §6.6.1 — role hierarchy VIEWER < ADMIN < OWNER.
// Enum index order encodes the hierarchy; atLeast() compares by index.
enum UserRole {
  viewer('VIEWER'),
  admin('ADMIN'),
  owner('OWNER');

  const UserRole(this.wireName);

  final String wireName;

  bool atLeast(UserRole minimum) => index >= minimum.index;
}

// EXECUTION-PLAN §6.6.2 — thrown by the repository layer before any data
// access when the session role is below the required minimum.
class AuthorizationException implements Exception {
  AuthorizationException(this.message);

  final String message;

  @override
  String toString() => 'AuthorizationException: $message';
}

class SessionContext {
  const SessionContext({
    required this.leagueId,
    this.userId,
    this.role = UserRole.viewer,
  });

  final String leagueId;
  final String? userId;
  final UserRole role;
}

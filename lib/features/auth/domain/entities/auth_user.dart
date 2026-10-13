import 'auth_session.dart';

/// The account as the backend knows it. Distinct from [AuthSession] because a
/// freshly registered user exists server-side (and has a token) before they
/// are allowed to count as signed in — that only happens once
/// [isEmailVerified] is true.
class AuthUser {
  final String id;
  final String name;
  final String email;
  final bool isEmailVerified;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isEmailVerified,
  });

  AuthSession toSession() => AuthSession(userId: id, email: email, name: name);
}

import 'auth_user.dart';

/// What Google or Apple gave the app after the person chose their account: the
/// proof the backend verifies.
class SocialCredential {
  /// The signed ID token (Google's `idToken`, Apple's `identityToken`).
  final String idToken;

  /// Apple only: the one-time code the backend needs so it can revoke the
  /// Apple token if the person deletes their account.
  final String? authorizationCode;

  /// Apple only, and only on a person's first sign-in: their name.
  final String? name;

  const SocialCredential({
    required this.idToken,
    this.authorizationCode,
    this.name,
  });
}

/// A successful Google or Apple sign-in.
class SocialSignIn {
  final AuthUser user;

  /// This sign-in created the account, so the person has not chosen a gender
  /// yet (neither provider shares it).
  final bool isNewUser;

  const SocialSignIn({required this.user, required this.isNewUser});
}

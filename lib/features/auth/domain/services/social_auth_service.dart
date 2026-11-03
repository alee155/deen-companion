import '../entities/social_sign_in.dart';

/// The Google and Apple sign-in sheets. Each call shows the provider's own UI
/// and returns what the backend needs, or null if the person closed the sheet
/// (which is not an error). Anything else that goes wrong throws
/// [SocialAuthException] with a sentence for the person.
abstract class SocialAuthService {
  Future<SocialCredential?> google();

  Future<SocialCredential?> apple();

  /// Sign in with Apple is offered on iPhone only.
  bool get appleSupported;
}

class SocialAuthException implements Exception {
  final String message;
  const SocialAuthException(this.message);

  @override
  String toString() => 'SocialAuthException: $message';
}

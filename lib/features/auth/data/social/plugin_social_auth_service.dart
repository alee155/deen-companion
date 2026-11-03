import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/social_sign_in.dart';
import '../../domain/services/social_auth_service.dart';

/// Google and Apple through their Flutter plugins.
class PluginSocialAuthService implements SocialAuthService {
  PluginSocialAuthService();

  Future<void>? _googleReady;

  /// The Google SDK is set up once, with the web client as `serverClientId`
  /// (the ID token is then issued for it, which is what the backend checks)
  /// and, on iPhone, the app's own iOS client.
  Future<void> _initGoogle() =>
      _googleReady ??= GoogleSignIn.instance.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? AppConstants.googleIosClientId
            : null,
        serverClientId: AppConstants.googleWebClientId,
      );

  @override
  Future<SocialCredential?> google() async {
    try {
      await _initGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthException(
          'Google didn’t give us what we need to sign you in. Please try again.',
        );
      }
      return SocialCredential(idToken: idToken);
    } on GoogleSignInException catch (e, st) {
      // The plugin reports some setup problems (an unregistered signing key on
      // Android, for one) as a cancel, so what it says is logged either way.
      AppLogger.d(
        'Google sign-in: ${e.code} ${e.description ?? ''} ${e.details ?? ''}',
      );
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      AppLogger.e('Google sign-in failed: ${e.code}', e, st);
      throw const SocialAuthException(
        'Couldn’t sign in with Google. Please try again.',
      );
    }
  }

  @override
  Future<SocialCredential?> apple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      final code = credential.authorizationCode;
      if (idToken == null || idToken.isEmpty || code.isEmpty) {
        throw const SocialAuthException(
          'Apple didn’t give us what we need to sign you in. Please try again.',
        );
      }
      // Apple shares the name once, on the very first sign-in, so it goes
      // along whenever there is one.
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().join(' ').trim();
      return SocialCredential(
        idToken: idToken,
        authorizationCode: code,
        name: name.isEmpty ? null : name,
      );
    } on SignInWithAppleAuthorizationException catch (e, st) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      AppLogger.e('Apple sign-in failed: ${e.code}', e, st);
      throw const SocialAuthException(
        'Couldn’t sign in with Apple. Please try again.',
      );
    }
  }

  @override
  bool get appleSupported => defaultTargetPlatform == TargetPlatform.iOS;
}

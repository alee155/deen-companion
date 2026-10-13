import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/auth_session.dart';
import 'auth_providers.dart';

/// The current identity: a guest until someone signs in. Persisted so the
/// session survives restarts; screens simply `watch` this and adapt.
///
/// The session ends when the user logs out, deletes their account, or the
/// backend rejects the access token (see [unauthorizedEventProvider]).
class AuthSessionNotifier extends Notifier<AuthSession> {
  static const _box = AppConstants.settingsBoxName;

  @override
  AuthSession build() {
    // Expired/revoked token detected by the network layer → back to guest.
    ref.listen(unauthorizedEventProvider, (_, _) => signOut());

    final storage = ref.read(localStorageServiceProvider);
    final userId = storage.get<String>(_box, AppConstants.authUserIdKey);
    if (userId == null) return const AuthSession.guest();
    Future.microtask(_validateOnLaunch);
    return AuthSession(
      userId: userId,
      email: storage.get<String>(_box, AppConstants.authEmailKey),
      name: storage.get<String>(_box, AppConstants.authNameKey),
      photoUrl: storage.get<String>(_box, AppConstants.authPhotoUrlKey),
    );
  }

  /// A restored session is only trusted if its token is still there, and the
  /// profile is refreshed from the server (which also surfaces an expired
  /// token as a 401 → sign out). Offline/server errors keep the session.
  Future<void> _validateOnLaunch() async {
    try {
      final token = await ref.read(tokenStorageProvider).readAccessToken();
      if (token == null || token.isEmpty) {
        await signOut();
        return;
      }
      await refresh();
    } catch (e, st) {
      AppLogger.e('AuthSession: launch validation failed', e, st);
    }
  }

  /// Re-reads the profile via `GET /auth/me` and updates the stored session.
  /// A 401 is handled by the interceptor (ends the session); other failures
  /// leave the session untouched.
  Future<void> refresh() async {
    final current = state;
    if (!current.isAuthenticated) return;
    final result = await ref.read(authRepositoryProvider).getCurrentUser();
    if (result case Success(:final data)) {
      if (state.userId == data.id) {
        await signIn(
          AuthSession(
            userId: data.id,
            email: data.email,
            name: data.name,
            photoUrl: current.photoUrl, // not part of the backend profile
          ),
        );
      }
    }
  }

  Future<void> signIn(AuthSession session) async {
    if (!session.isAuthenticated) return;
    state = session;
    final storage = ref.read(localStorageServiceProvider);
    await storage.put(_box, AppConstants.authUserIdKey, session.userId);
    Future<void> save(String key, String? v) =>
        v == null ? storage.delete(_box, key) : storage.put(_box, key, v);
    await save(AppConstants.authEmailKey, session.email);
    await save(AppConstants.authNameKey, session.name);
    await save(AppConstants.authPhotoUrlKey, session.photoUrl);
  }

  Future<void> signOut() async {
    state = const AuthSession.guest();
    await ref.read(tokenStorageProvider).clear();
    final storage = ref.read(localStorageServiceProvider);
    for (final key in [
      AppConstants.authUserIdKey,
      AppConstants.authEmailKey,
      AppConstants.authNameKey,
      AppConstants.authPhotoUrlKey,
    ]) {
      await storage.delete(_box, key);
    }
  }
}

final authSessionProvider = NotifierProvider<AuthSessionNotifier, AuthSession>(
  AuthSessionNotifier.new,
);

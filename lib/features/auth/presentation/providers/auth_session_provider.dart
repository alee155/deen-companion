import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/auth_session.dart';

/// The current identity: a guest until someone signs in. Persisted so the
/// session survives restarts; screens simply `watch` this and adapt.
class AuthSessionNotifier extends Notifier<AuthSession> {
  static const _box = AppConstants.settingsBoxName;

  @override
  AuthSession build() {
    final storage = ref.read(localStorageServiceProvider);
    final userId = storage.get<String>(_box, AppConstants.authUserIdKey);
    if (userId == null) return const AuthSession.guest();
    return AuthSession(
      userId: userId,
      email: storage.get<String>(_box, AppConstants.authEmailKey),
      name: storage.get<String>(_box, AppConstants.authNameKey),
      photoUrl: storage.get<String>(_box, AppConstants.authPhotoUrlKey),
    );
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

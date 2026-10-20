import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/timezone/device_timezone.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../auth/presentation/providers/session_keep_alive.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider)),
);

/// The avatar link is signed and expires, so this is kept only briefly.
const profileKeepAlive = Duration(minutes: 5);

/// The signed-in user's profile. On every successful read the name and
/// picture are mirrored into the stored session, and the server's timezone is
/// corrected if the device has moved to another one. A guest has no profile.
final profileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  keepAliveForSession(ref, profileKeepAlive);
  final signedIn = ref.watch(
    authSessionProvider.select((s) => s.isAuthenticated),
  );
  if (!signedIn) return null;
  final repo = ref.watch(profileRepositoryProvider);
  final result = await repo.getProfile();
  final profile = result.when(success: (d) => d, failure: (f) => throw f);

  await ref
      .read(authSessionProvider.notifier)
      .applyProfile(name: profile.name, photoUrl: profile.avatarUrl);
  await _syncTimezone(ref, repo, profile);
  return profile;
});

/// Best effort: a failure here must never block showing the profile.
Future<void> _syncTimezone(
  Ref ref,
  ProfileRepository repo,
  UserProfile profile,
) async {
  final device = await ref.read(deviceTimezoneProvider).iana();
  if (device == null || device == profile.timezone) return;
  await repo.setTimezone(device);
}

/// Total points and what each group has earned.
final myPointsProvider = FutureProvider.autoDispose<UserPoints>((ref) async {
  keepAliveForSession(ref, profileKeepAlive);
  final signedIn = ref.watch(
    authSessionProvider.select((s) => s.isAuthenticated),
  );
  if (!signedIn) return UserPoints.empty;
  final result = await ref.watch(profileRepositoryProvider).getPoints();
  return result.when(success: (d) => d, failure: (f) => throw f);
});

class ProfileEditState {
  final bool isSaving;
  final String? errorMessage;
  const ProfileEditState({this.isSaving = false, this.errorMessage});
}

/// Saves edits to the profile. The screen only shows [state] and calls
/// [save] or [removePhoto]; the request and the refresh of what depends on it
/// live here.
class ProfileEditController extends AutoDisposeNotifier<ProfileEditState> {
  @override
  ProfileEditState build() => const ProfileEditState();

  /// True once saved. Only what changed is sent.
  Future<bool> save({String? name, String? imagePath}) => _run(
    () => ref
        .read(profileRepositoryProvider)
        .updateProfile(name: name, imagePath: imagePath),
  );

  Future<bool> removePhoto() =>
      _run(() => ref.read(profileRepositoryProvider).removeAvatar());

  Future<bool> _run(Future<Result<UserProfile>> Function() call) async {
    if (state.isSaving) return false;
    state = const ProfileEditState(isSaving: true);
    final result = await call();
    switch (result) {
      case Success(:final data):
        await ref
            .read(authSessionProvider.notifier)
            .applyProfile(name: data.name, photoUrl: data.avatarUrl);
        ref.invalidate(profileProvider);
        // Groups keep the member list (with pictures and names) for a while;
        // drop it so the change shows there too.
        ref.invalidate(groupDetailProvider);
        ref.invalidate(myGroupsProvider);
        state = const ProfileEditState();
        return true;
      case Error(:final failure):
        state = ProfileEditState(errorMessage: failure.message);
        return false;
    }
  }
}

final profileEditControllerProvider =
    NotifierProvider.autoDispose<ProfileEditController, ProfileEditState>(
      ProfileEditController.new,
    );

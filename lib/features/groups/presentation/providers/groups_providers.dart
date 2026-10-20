import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/state/keep_alive_for.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/groups_remote_datasource.dart';
import '../../data/repositories/groups_repository_impl.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_detail.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/entities/invite_preview.dart';
import '../../domain/repositories/groups_repository.dart';

final groupsRemoteDataSourceProvider = Provider<GroupsRemoteDataSource>(
  (ref) => GroupsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) =>
      GroupsRepositoryImpl(remote: ref.watch(groupsRemoteDataSourceProvider)),
);

class MyGroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
    // Groups belong to an account: guests have none, and the list reloads
    // when someone signs in or out.
    final signedIn = ref.watch(
      authSessionProvider.select((s) => s.isAuthenticated),
    );
    if (!signedIn) return const [];
    final result = await ref.read(groupsRepositoryProvider).getMyGroups();
    return result.when(success: (d) => d, failure: (f) => throw f);
  }

  /// Returns the created group, or throws the failure message to the caller
  /// via [Result] so the form can show it inline.
  Future<Result<Group>> create(NewGroup input) async {
    final result = await ref.read(groupsRepositoryProvider).createGroup(input);
    if (result case Success(:final data)) {
      state = AsyncData([data, ...?state.valueOrNull]);
    }
    return result;
  }

  /// Admin only. Keeps the caller's role/other list-only fields.
  Future<Result<Group>> updateGroup(
    String groupId, {
    required String name,
    required String description,
  }) async {
    final result = await ref
        .read(groupsRepositoryProvider)
        .updateGroup(groupId, name: name, description: description);
    if (result case Success(:final data)) {
      state = AsyncData([
        for (final g in state.valueOrNull ?? const <Group>[])
          if (g.id == groupId) g.withUpdate(data) else g,
      ]);
    }
    return result;
  }

  /// Leaves the group and drops it from the list. (The backend deletes the
  /// group if this was the last member.)
  Future<Result<void>> leaveGroup(String groupId) async {
    final result = await ref.read(groupsRepositoryProvider).leaveGroup(groupId);
    if (result is Success) {
      state = AsyncData([
        for (final g in state.valueOrNull ?? const <Group>[])
          if (g.id != groupId) g,
      ]);
    }
    return result;
  }

  /// Admin only.
  Future<Result<void>> deleteGroup(String groupId) async {
    final result = await ref
        .read(groupsRepositoryProvider)
        .deleteGroup(groupId);
    if (result is Success) {
      state = AsyncData([
        for (final g in state.valueOrNull ?? const <Group>[])
          if (g.id != groupId) g,
      ]);
    }
    return result;
  }
}

final myGroupsProvider = AsyncNotifierProvider<MyGroupsNotifier, List<Group>>(
  MyGroupsNotifier.new,
);

/// How long a group's data is kept after its screen is closed. Reopening the
/// group within this time shows it at once (and refreshes it quietly) instead
/// of a loading skeleton.
const groupDataKeepAlive = Duration(minutes: 15);

/// Full group (with members) for the detail screen.
///
/// Kept for [groupDataKeepAlive] after the screen closes, and dropped at once
/// when another account signs in: members' names and e-mails must never be
/// shown to the next person.
final groupDetailProvider = FutureProvider.autoDispose
    .family<GroupDetail, String>((ref, groupId) async {
      final link = keepAliveFor(ref, groupDataKeepAlive);
      ref.listen(authSessionProvider.select((s) => s.userId), (_, _) {
        FlowLog.log('GROUP', 'ACCOUNT CHANGED -> DROPPING THE KEPT GROUP DATA');
        link.close();
      });
      final result = await ref
          .watch(groupsRepositoryProvider)
          .getGroupDetail(groupId);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

class GroupManageState {
  final bool isSaving;
  final bool isDeleting;
  final bool isLeaving;

  /// The member currently being removed, if any.
  final String? removingUserId;
  final String? errorMessage;

  const GroupManageState({
    this.isSaving = false,
    this.isDeleting = false,
    this.isLeaving = false,
    this.removingUserId,
    this.errorMessage,
  });

  bool get isBusy =>
      isSaving || isDeleting || isLeaving || removingUserId != null;
}

/// Actions on one group: edit/delete/remove-member (admin only — enforced by
/// the backend, and only offered to admins in the UI) and leave (anyone).
class GroupManageController extends AutoDisposeNotifier<GroupManageState> {
  @override
  GroupManageState build() => const GroupManageState();

  void clearError() {
    if (state.errorMessage != null && !state.isBusy) {
      state = const GroupManageState();
    }
  }

  Future<bool> update(
    String groupId, {
    required String name,
    required String description,
  }) async {
    if (state.isBusy) return false;
    state = const GroupManageState(isSaving: true);
    final result = await ref
        .read(myGroupsProvider.notifier)
        .updateGroup(groupId, name: name, description: description);
    switch (result) {
      case Success():
        ref.invalidate(groupDetailProvider(groupId));
        state = const GroupManageState();
        return true;
      case Error(:final failure):
        state = GroupManageState(errorMessage: failure.message);
        return false;
    }
  }

  Future<bool> delete(String groupId) async {
    if (state.isBusy) return false;
    state = const GroupManageState(isDeleting: true);
    final result = await ref
        .read(myGroupsProvider.notifier)
        .deleteGroup(groupId);
    switch (result) {
      case Success():
        state = const GroupManageState();
        return true;
      case Error(:final failure):
        state = GroupManageState(errorMessage: failure.message);
        return false;
    }
  }

  /// Admin removes [userId]. On success the group's member list (and the
  /// numbers derived from it) is reloaded.
  Future<bool> removeMember(String groupId, String userId) async {
    if (state.isBusy) return false;
    state = GroupManageState(removingUserId: userId);
    final result = await ref
        .read(groupsRepositoryProvider)
        .removeMember(groupId, userId);
    switch (result) {
      case Success():
        ref.invalidate(groupDetailProvider(groupId));
        state = const GroupManageState();
        return true;
      case Error(:final failure):
        state = GroupManageState(errorMessage: failure.message);
        return false;
    }
  }

  /// The signed-in user leaves; the group disappears from their list.
  Future<bool> leave(String groupId) async {
    if (state.isBusy) return false;
    state = const GroupManageState(isLeaving: true);
    final result = await ref
        .read(myGroupsProvider.notifier)
        .leaveGroup(groupId);
    switch (result) {
      case Success():
        state = const GroupManageState();
        return true;
      case Error(:final failure):
        state = GroupManageState(errorMessage: failure.message);
        return false;
    }
  }
}

final groupManageControllerProvider =
    NotifierProvider.autoDispose<GroupManageController, GroupManageState>(
      GroupManageController.new,
    );

/// A group's invite link, keyed by the group id from the API (never
/// hardcoded). [reset] swaps in the freshly generated link.
class GroupInviteNotifier
    extends AutoDisposeFamilyAsyncNotifier<GroupInvite, String> {
  @override
  Future<GroupInvite> build(String groupId) async {
    final result = await ref.read(groupsRepositoryProvider).getInvite(groupId);
    return result.when(success: (d) => d, failure: (f) => throw f);
  }

  /// Returns null on success, or the error message. While running, [state] is
  /// loading but keeps the previous link; on failure the old link is kept.
  Future<String?> reset() async {
    final previous = state;
    if (previous.isLoading) return null;
    state = const AsyncLoading<GroupInvite>().copyWithPrevious(previous);
    final result = await ref.read(groupsRepositoryProvider).resetInvite(arg);
    switch (result) {
      case Success(:final data):
        state = AsyncData(data);
        return null;
      case Error(:final failure):
        state = previous;
        return failure.message;
    }
  }
}

final groupInviteProvider = AsyncNotifierProvider.autoDispose
    .family<GroupInviteNotifier, GroupInvite, String>(GroupInviteNotifier.new);

/// Preview for an invite token. Re-fetched when the user signs in/out, since
/// `isMember` is only known when authenticated.
final invitePreviewProvider = FutureProvider.autoDispose
    .family<InvitePreview, String>((ref, token) async {
      ref.watch(authSessionProvider.select((s) => s.userId));
      final result = await ref
          .watch(groupsRepositoryProvider)
          .previewInvite(token);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

class JoinGroupState {
  final bool isJoining;
  final String? errorMessage;

  const JoinGroupState({this.isJoining = false, this.errorMessage});
}

class JoinGroupController extends AutoDisposeNotifier<JoinGroupState> {
  @override
  JoinGroupState build() => const JoinGroupState();

  /// Returns the join result, or null on failure (see [state]). On success the
  /// user's group list is refreshed so the new group shows up.
  Future<JoinResult?> join(String token) async {
    if (state.isJoining) return null;
    state = const JoinGroupState(isJoining: true);
    final result = await ref.read(groupsRepositoryProvider).joinGroup(token);
    switch (result) {
      case Success(:final data):
        ref.invalidate(myGroupsProvider);
        state = const JoinGroupState();
        return data;
      case Error(:final failure):
        state = JoinGroupState(errorMessage: failure.message);
        return null;
    }
  }
}

final joinGroupControllerProvider =
    NotifierProvider.autoDispose<JoinGroupController, JoinGroupState>(
      JoinGroupController.new,
    );

/// How many groups the signed-in user created.
final ownedGroupsCountProvider = Provider.autoDispose<int>((ref) {
  final groups = ref.watch(myGroupsProvider).valueOrNull ?? const [];
  return groups.where((g) => g.isOwner).length;
});

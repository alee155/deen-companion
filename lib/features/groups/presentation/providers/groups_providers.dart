import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/datasources/groups_local_datasource.dart';
import '../../data/repositories/groups_repository_impl.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_streak.dart';
import '../../domain/repositories/groups_repository.dart';

/// Kept alive for the app's lifetime so the in-memory store (and therefore
/// groups created this session) survives navigation.
final groupsDataSourceProvider = Provider<GroupsLocalDataSource>(
  (ref) => GroupsLocalDataSource(),
);

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => GroupsRepositoryImpl(ref.watch(groupsDataSourceProvider)),
);

class MyGroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
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
}

final myGroupsProvider = AsyncNotifierProvider<MyGroupsNotifier, List<Group>>(
  MyGroupsNotifier.new,
);

final groupStreakProvider = FutureProvider.autoDispose
    .family<GroupStreakSummary, String>((ref, groupId) async {
      final result = await ref
          .watch(groupsRepositoryProvider)
          .getGroupStreak(groupId);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

final myStreakStatsProvider = FutureProvider.autoDispose<UserStreakStats>((
  ref,
) async {
  final result = await ref.watch(groupsRepositoryProvider).getMyStreakStats();
  return result.when(success: (d) => d, failure: (f) => throw f);
});

/// How many groups the signed-in user created.
final ownedGroupsCountProvider = Provider.autoDispose<int>((ref) {
  final groups = ref.watch(myGroupsProvider).valueOrNull ?? const [];
  return groups.where((g) => g.isOwner).length;
});

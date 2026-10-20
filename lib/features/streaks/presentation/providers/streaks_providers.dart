import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../auth/presentation/providers/session_keep_alive.dart';
import '../../data/datasources/streaks_remote_datasource.dart';
import '../../data/repositories/streaks_repository_impl.dart';
import '../../domain/entities/group_streaks.dart';
import '../../domain/entities/my_streaks.dart';
import '../../domain/entities/streak_rule.dart';
import '../../domain/repositories/streaks_repository.dart';

final streaksRemoteDataSourceProvider = Provider<StreaksRemoteDataSource>(
  (ref) => StreaksRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final streaksRepositoryProvider = Provider<StreaksRepository>(
  (ref) => StreaksRepositoryImpl(ref.watch(streaksRemoteDataSourceProvider)),
);

/// How long streak numbers are kept after their screen closes. Short: they
/// change whenever anyone in the group logs a prayer.
const streaksKeepAlive = Duration(minutes: 2);

/// Bumped whenever a prayer is logged or removed (or the daily goal changes).
/// Every streak read watches it, so what is on screen refetches and what
/// nobody is looking at does nothing: invalidating a provider directly would
/// fetch it even if it was never used.
final streaksRevisionProvider = StateProvider<int>((ref) => 0);

/// A group's streak board: who is on a run and who has done today's goal.
final groupStreakBoardProvider = FutureProvider.autoDispose
    .family<GroupStreakBoard, String>((ref, groupId) async {
      keepAliveForSession(ref, streaksKeepAlive);
      ref.watch(streaksRevisionProvider);
      final result = await ref
          .watch(streaksRepositoryProvider)
          .getBoard(groupId);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

/// What the group asks of a day.
final streakRuleProvider = FutureProvider.autoDispose
    .family<StreakRule, String>((ref, groupId) async {
      keepAliveForSession(ref, streaksKeepAlive);
      ref.watch(streaksRevisionProvider);
      final result = await ref
          .watch(streaksRepositoryProvider)
          .getRule(groupId);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

/// The signed-in user's streaks, per group and per prayer. Empty for a guest:
/// streaks belong to an account.
final myStreaksProvider = FutureProvider.autoDispose<MyStreaks>((ref) async {
  keepAliveForSession(ref, streaksKeepAlive);
  ref.watch(streaksRevisionProvider);
  final signedIn = ref.watch(
    authSessionProvider.select((s) => s.isAuthenticated),
  );
  if (!signedIn) return MyStreaks.empty;
  final result = await ref.watch(streaksRepositoryProvider).getMine();
  return result.when(success: (d) => d, failure: (f) => throw f);
});

/// Streak numbers change whenever a prayer is logged or removed; call this so
/// the next read asks the server again.
void invalidateStreaks(Ref ref) {
  ref.read(streaksRevisionProvider.notifier).state++;
}

class StreakRuleState {
  final bool isSaving;
  final String? errorMessage;
  const StreakRuleState({this.isSaving = false, this.errorMessage});
}

/// Changes a group's daily goal (admin only). The screen only shows [state]
/// and calls [save]; the request and the refresh of what depends on it live
/// here.
class StreakRuleController extends AutoDisposeNotifier<StreakRuleState> {
  @override
  StreakRuleState build() => const StreakRuleState();

  /// True once the rule is saved (or already was that value).
  Future<bool> save(String groupId, int minPrayers) async {
    if (state.isSaving) return false;
    state = const StreakRuleState(isSaving: true);
    final result = await ref
        .read(streaksRepositoryProvider)
        .setRule(groupId, minPrayers);
    switch (result) {
      case Success():
        ref.invalidate(streakRuleProvider(groupId));
        ref.invalidate(groupStreakBoardProvider(groupId));
        ref.invalidate(myStreaksProvider);
        state = const StreakRuleState();
        return true;
      case Error(:final failure):
        state = StreakRuleState(errorMessage: failure.message);
        return false;
    }
  }
}

final streakRuleControllerProvider =
    NotifierProvider.autoDispose<StreakRuleController, StreakRuleState>(
      StreakRuleController.new,
    );

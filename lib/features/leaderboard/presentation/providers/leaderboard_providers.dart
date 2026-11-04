import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/session_keep_alive.dart';
import '../../../group_live/presentation/providers/group_live_store.dart';
import '../../data/datasources/leaderboard_remote_datasource.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';

final leaderboardRemoteDataSourceProvider =
    Provider<LeaderboardRemoteDataSource>(
      (ref) => LeaderboardRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) =>
      LeaderboardRepositoryImpl(ref.watch(leaderboardRemoteDataSourceProvider)),
);

/// How long a board is kept after its screen closes. Short: it changes
/// whenever anyone logs a prayer.
const leaderboardKeepAlive = Duration(minutes: 2);

/// The group's ranking, best first.
///
/// The board is not pushed over the socket, but the group's live summary is,
/// and it carries every member's points. So the board is fetched again when
/// those points change, instead of on a timer: a prayer logged by anyone moves
/// the ranking on screen within a moment, and nothing is fetched while nothing
/// changes.
final groupLeaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, String>((ref, groupId) async {
      keepAliveForSession(ref, leaderboardKeepAlive);
      ref.watch(
        groupLiveProvider(groupId).select(
          (s) => s.summary?.members
              .map((m) => '${m.userId}:${m.points}:${m.currentStreak}')
              .join(','),
        ),
      );
      final result = await ref
          .watch(leaderboardRepositoryProvider)
          .leaderboard(groupId);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

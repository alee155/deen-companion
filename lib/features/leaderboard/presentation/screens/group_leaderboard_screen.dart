import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../providers/leaderboard_providers.dart';
import '../widgets/leaderboard_podium.dart';
import '../widgets/leaderboard_rows.dart';

/// A group's ranking: the top three on a podium, then everyone else in order.
/// Points count from the day each member joined, so a newcomer is not behind
/// by the days before they were there. Built from the same pieces as the
/// Statistics screen: the dark hero, the pinned bar, pull to refresh.
class GroupLeaderboardScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupLeaderboardScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupLeaderboardScreen> createState() =>
      _GroupLeaderboardScreenState();
}

class _GroupLeaderboardScreenState
    extends ConsumerState<GroupLeaderboardScreen> {
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 140 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _bar.value) _bar.value = t;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(groupLeaderboardProvider(widget.groupId));
    try {
      await ref.read(groupLeaderboardProvider(widget.groupId).future);
    } catch (_) {}
  }

  List<FeatureHeroChip> _chips(List<LeaderboardEntry>? entries, String? myId) {
    if (entries == null) return const [];
    final mine = entries.where((e) => e.userId == myId).firstOrNull;
    return [
      if (mine != null) ...[
        FeatureHeroChip(
          Icons.emoji_events_rounded,
          'You’re #${mine.rank} of ${entries.length}',
        ),
        FeatureHeroChip(Icons.stars_rounded, '${mine.points} pts'),
      ] else
        FeatureHeroChip(Icons.groups_rounded, '${entries.length} members'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authSessionProvider).userId;
    final group = ref.watch(groupDetailProvider(widget.groupId)).valueOrNull;
    final board = ref.watch(groupLeaderboardProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            RefreshIndicator(
              edgeOffset: 90.h,
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: FeatureHero(
                      title: 'Leaderboard',
                      subtitle:
                          group?.name ?? 'Points since each member joined',
                      ghostIcon: Icons.leaderboard_rounded,
                      compact: true,
                      chips: _chips(board.valueOrNull, myId),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 0),
                    sliver: SliverToBoxAdapter(
                      // A refresh keeps the board on screen instead of
                      // flashing a skeleton over it.
                      child: board.when(
                        skipLoadingOnRefresh: true,
                        skipLoadingOnReload: true,
                        loading: _skeleton,
                        error: (e, _) => FailureView(
                          failure: failureFrom(e),
                          onRetry: () async => ref.invalidate(
                            groupLeaderboardProvider(widget.groupId),
                          ),
                        ),
                        data: (entries) => _board(entries, group, myId),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 32.h,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(
                opacity: _bar,
                title: 'Leaderboard',
                shadow: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeleton() => Column(
    children: [
      ShimmerBox(width: double.infinity, height: 190.h, borderRadius: 24.r),
      SizedBox(height: 16.h),
      ShimmerBox(width: double.infinity, height: 220.h, borderRadius: 24.r),
    ],
  );

  Widget _board(List<LeaderboardEntry> entries, group, String? myId) {
    if (entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Text(
          'No one is on the leaderboard yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
        ),
      );
    }
    // The podium needs three; a smaller group is just the list.
    final podium = entries.length >= 3;
    final rest = podium ? entries.skip(3).toList() : entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (podium) ...[
          LeaderboardPodium(
            topThree: entries.take(3).toList(),
            group: group,
            myId: myId,
          ).slideIn(RevealDirection.bottom, distance: 18),
          SizedBox(height: 20.h),
        ],
        if (rest.isNotEmpty)
          LeaderboardRows(entries: rest, group: group, myId: myId).slideIn(
            RevealDirection.bottom,
            distance: 18,
            delay: const Duration(milliseconds: 80),
          ),
        SizedBox(height: 14.h),
        Text(
          'Points count from the day each member joined the group.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

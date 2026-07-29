import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../features/audio_player/presentation/providers/audio_player_provider.dart';
import '../../features/audio_player/presentation/widgets/mini_player_bar.dart';
import '../theme/app_colors.dart';

/// Shell around the bottom-tab destinations (Home / Favorites / Recent /
/// Profile).
///
/// This widget is built once by the router's StatefulShellRoute and stays
/// mounted for the lifetime of the tabbed section of the app — only the
/// active branch's content underneath (`navigationShell`) changes when a
/// tab is tapped. That's what keeps the bottom nav bar itself visible and
/// interactive at all times: it's part of this persistent shell, not part
/// of whatever screen currently happens to be showing.
///
/// Each tab also gets its own independent Navigator + back stack from
/// [StatefulNavigationShell], so pushing screens within a tab doesn't
/// affect the other tabs, and switching tabs and back preserves scroll
/// position/state.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  static const List<String> _labels = [
    'Home',
    'Favorites',
    'Recent',
    'Profile',
  ];
  static const List<IconData> _icons = [
    Icons.home_outlined,
    Icons.favorite_outline,
    Icons.history,
    Icons.person_outline,
  ];
  static const List<IconData> _iconsFilled = [
    Icons.home,
    Icons.favorite,
    Icons.history,
    Icons.person,
  ];

  void _onTabTapped(int index) {
    // `initialLocation: true` when re-tapping the already-selected tab pops
    // that tab's stack back to its root, matching standard bottom-nav
    // behavior (e.g. tapping "Home" again from a pushed screen returns to
    // the Home tab's root instead of doing nothing).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerNotifierProvider);
    final selectedIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Docked above the nav bar only when a track is loaded.
          if (audioState.hasTrack)
            MiniPlayerBar(
              title: audioState.track!.titleEnglish,
              subtitle: audioState.track!.reciterName,
              isPlaying: audioState.isPlaying,
              progress: audioState.duration.inMilliseconds == 0
                  ? 0.0
                  : audioState.position.inMilliseconds /
                        audioState.duration.inMilliseconds,
              onTap: () => context.push('/player'),
              onPlayPause: () => ref
                  .read(audioPlayerNotifierProvider.notifier)
                  .togglePlayPause(),
              onClose: () =>
                  ref.read(audioPlayerNotifierProvider.notifier).stop(),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(top: BorderSide(color: AppColors.borderWarm)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 58.h,
                child: Row(
                  children: List.generate(_labels.length, (index) {
                    final isSelected = index == selectedIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () => _onTabTapped(index),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              switchInCurve: Curves.easeOutBack,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                isSelected
                                    ? _iconsFilled[index]
                                    : _icons[index],
                                key: ValueKey(isSelected),
                                color: isSelected
                                    ? AppColors.emeraldInk
                                    : AppColors.textMuted,
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: isSelected
                                    ? AppColors.emeraldInk
                                    : AppColors.textMuted,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              child: Text(_labels[index]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

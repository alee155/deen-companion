import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/audio_player/presentation/providers/audio_player_provider.dart';
import '../../features/audio_player/presentation/widgets/mini_player_bar.dart';
import '../motion/motion.dart';
import '../widgets/floating_nav_bar.dart';

/// Shell around the bottom-tab destinations (Home / Favorites / Settings /
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

  static const List<FloatingNavItem> _items = [
    FloatingNavItem(icon: Icons.home_rounded, label: 'Home'),
    FloatingNavItem(icon: Icons.favorite_rounded, label: 'Favorites'),
    FloatingNavItem(icon: Icons.group, label: 'Groups'),
    FloatingNavItem(icon: Icons.settings_rounded, label: 'Settings'),
    FloatingNavItem(icon: Icons.person_rounded, label: 'Profile'),
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

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Docked above the nav bar only when a track is loaded.
          AnimatedSize(
            duration: context.motion.duration(AppMotion.normal),
            curve: AppMotion.emphasized,
            alignment: Alignment.bottomCenter,
            child: ContentSwitcher(
              alignment: Alignment.bottomCenter,
              child: !audioState.hasTrack
                  ? const SizedBox(
                      key: ValueKey('no-mini'),
                      width: double.infinity,
                    )
                  : MiniPlayerBar(
                      key: const ValueKey('mini'),
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
            ),
          ),
          FloatingNavBar(
            currentIndex: navigationShell.currentIndex,
            onTap: _onTabTapped,
            items: _items,
          ),
        ],
      ),
    );
  }
}

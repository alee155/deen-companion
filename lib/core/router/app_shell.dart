import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../features/audio_player/presentation/providers/audio_player_provider.dart';
import '../../features/audio_player/presentation/widgets/mini_player_bar.dart';
import '../theme/app_colors.dart';
import 'app_routes.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  static const List<String> _routes = [
    AppRoutes.home,
    AppRoutes.quran,
    AppRoutes.prayerTimes,
    AppRoutes.learn,
  ];

  static const List<String> _labels = ['Home', 'Quran', 'Prayer', 'Learn'];
  static const List<IconData> _icons = [
    Icons.home_outlined,
    Icons.menu_book_outlined,
    Icons.access_time_outlined,
    Icons.library_books_outlined,
  ];
  static const List<IconData> _iconsFilled = [
    Icons.home,
    Icons.menu_book,
    Icons.access_time_filled,
    Icons.library_books,
  ];

  void _onTabTapped(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      GoRouter.of(context).go(_routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioPlayerNotifierProvider);

    return Scaffold(
      body: widget.child,
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
                  children: List.generate(_routes.length, (index) {
                    final isSelected = index == _selectedIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () => _onTabTapped(index),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected ? _iconsFilled[index] : _icons[index],
                              color: isSelected
                                  ? AppColors.emeraldInk
                                  : AppColors.textMuted,
                              size: 20.sp,
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              _labels[index],
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: isSelected
                                    ? AppColors.emeraldInk
                                    : AppColors.textMuted,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
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

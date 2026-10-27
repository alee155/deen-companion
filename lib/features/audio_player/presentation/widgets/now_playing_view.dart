import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import 'mihrab_artwork.dart';
import 'player_controls.dart';
import 'player_scrubber.dart';
import 'player_sheets.dart';

/// The full-screen player.
///
/// Laid out the way people already expect a music player to work (artwork,
/// title with its actions, a scrubber, transport controls, a row of options),
/// but with this app's own artwork, palette and recitation-specific controls.
/// Everything is passed in, so the view holds no playback logic.
class NowPlayingView extends StatelessWidget {
  final String titleArabic;
  final String titleEnglish;
  final String reciterName;
  final int? surahNumber;
  final FavoriteItem favoriteItem;

  final bool isPlaying;
  final bool isLooping;
  final double speed;
  final Duration position;
  final Duration duration;
  final Duration? sleepTimerRemaining;

  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onBack10;
  final VoidCallback onForward10;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onToggleLoop;
  final ValueChanged<double> onSetSpeed;
  final ValueChanged<Duration> onSetSleepTimer;
  final VoidCallback onCancelSleepTimer;

  /// Stop playback and close the player.
  final VoidCallback onStop;

  /// Close the player and keep playing (the mini player takes over).
  final VoidCallback onMinimize;

  const NowPlayingView({
    super.key,
    required this.titleArabic,
    required this.titleEnglish,
    required this.reciterName,
    required this.surahNumber,
    required this.favoriteItem,
    required this.isPlaying,
    required this.isLooping,
    required this.speed,
    required this.position,
    required this.duration,
    required this.sleepTimerRemaining,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onBack10,
    required this.onForward10,
    required this.onSeek,
    required this.onToggleLoop,
    required this.onSetSpeed,
    required this.onSetSleepTimer,
    required this.onCancelSleepTimer,
    required this.onStop,
    required this.onMinimize,
  });

  @override
  Widget build(BuildContext context) {
    final hasTimer = sleepTimerRemaining != null;

    // Material for the menu and its ink, wherever this view is placed.
    return Material(
      type: MaterialType.transparency,
      child: _background(context, hasTimer: hasTimer),
    );
  }

  Widget _background(BuildContext context, {required bool hasTimer}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF16110D),
            const Color(0xFF241812),
            Color.lerp(const Color(0xFF241812), AppColors.amberDeep, 0.55)!,
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.045),
              cell: 56,
            ),
          ),
          // Warm light behind the artwork.
          Positioned(
            top: -40.h,
            left: -60.w,
            right: -60.w,
            child: IgnorePointer(
              child: Container(
                height: 440.h,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.62,
                    colors: [
                      AppColors.amber.withValues(alpha: 0.26),
                      AppColors.amber.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // A downward fling closes the player, like the sheet it is.
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 600) onMinimize();
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    _Grabber(onTap: onMinimize),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final byHeight =
                              (box.maxHeight - 12) / MihrabArtwork.heightFor(1);
                          final width = math.max(
                            150.0,
                            math.min(
                              math.min(box.maxWidth * 0.74, byHeight),
                              320.0,
                            ),
                          );
                          return Center(
                            child: MihrabArtwork(
                              arabicTitle: titleArabic,
                              number: surahNumber,
                              isPlaying: isPlaying,
                              width: width,
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 14.h),
                    _TitleRow(
                      titleEnglish: titleEnglish,
                      reciterName: reciterName,
                      favoriteItem: favoriteItem,
                      onStop: onStop,
                    ),
                    SizedBox(height: 12.h),
                    PlayerScrubber(
                      position: position,
                      duration: duration,
                      onSeek: onSeek,
                    ),
                    SizedBox(height: 8.h),
                    PlayerTransport(
                      isPlaying: isPlaying,
                      onPlayPause: onPlayPause,
                      onPrevious: onPrevious,
                      onNext: onNext,
                      onBack10: onBack10,
                      onForward10: onForward10,
                    ),
                    SizedBox(height: 18.h),
                    Row(
                      children: [
                        PlayerPill(
                          icon: Icons.repeat_one_rounded,
                          label: isLooping ? 'Repeat on' : 'Repeat',
                          active: isLooping,
                          semanticLabel: isLooping
                              ? 'Turn repeat off'
                              : 'Repeat this surah',
                          onTap: onToggleLoop,
                        ),
                        SizedBox(width: 10.w),
                        PlayerPill(
                          label: speedLabel(speed),
                          icon: Icons.speed_rounded,
                          active: speed != 1.0,
                          semanticLabel: 'Playback speed',
                          onTap: () => showSpeedSheet(
                            context,
                            current: speed,
                            onSelect: onSetSpeed,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        PlayerPill(
                          icon: hasTimer
                              ? Icons.bedtime_rounded
                              : Icons.bedtime_outlined,
                          label: hasTimer
                              ? formatPlayerTime(sleepTimerRemaining!)
                              : 'Sleep',
                          active: hasTimer,
                          semanticLabel: 'Sleep timer',
                          onTap: () => showSleepTimerSheet(
                            context,
                            remaining: sleepTimerRemaining,
                            onSelect: onSetSleepTimer,
                            onTurnOff: onCancelSleepTimer,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  final VoidCallback onTap;
  const _Grabber({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Minimise player',
      scale: 1,
      child: SizedBox(
        height: 30.h,
        width: 120.w,
        child: Center(
          child: Container(
            width: 40.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final String titleEnglish;
  final String reciterName;
  final FavoriteItem favoriteItem;
  final VoidCallback onStop;
  const _TitleRow({
    required this.titleEnglish,
    required this.reciterName,
    required this.favoriteItem,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleEnglish,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heroSerif.copyWith(
                  color: AppColors.onHeroSurface,
                  fontSize: 26.sp,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                reciterName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldLight.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10.w),
        _FavoriteButton(item: favoriteItem),
        SizedBox(width: 8.w),
        _MoreMenu(onStop: onStop),
      ],
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  final FavoriteItem item;
  const _FavoriteButton({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(item.id));
    return PlayerRoundButton(
      semanticLabel: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      onTap: () => ref.read(favoritesNotifierProvider.notifier).toggle(item),
      child: IconSwap(
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(isFavorite),
          size: 20.sp,
          color: isFavorite ? AppColors.amber : AppColors.onHeroSurface,
        ),
      ),
    );
  }
}

enum _MoreAction { stop }

class _MoreMenu extends StatelessWidget {
  final VoidCallback onStop;
  const _MoreMenu({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MoreAction>(
      tooltip: 'More',
      color: const Color(0xFF2A211B),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      // (A menu item with no value counts as dismissed, so it needs one.)
      onSelected: (action) {
        if (action == _MoreAction.stop) onStop();
      },
      itemBuilder: (_) => [
        PopupMenuItem<_MoreAction>(
          value: _MoreAction.stop,
          child: Row(
            children: [
              Icon(
                Icons.stop_circle_outlined,
                size: 20.sp,
                color: const Color(0xFFFF8A7A),
              ),
              SizedBox(width: 10.w),
              Text(
                'Stop playback',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onHeroSurface,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 22.sp,
          color: AppColors.onHeroSurface,
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// Warm, on-brand tones for text/icons that sit on the dark espresso
// background — replaces the old cool blue-green greys that didn't match
// the rest of the app's warm gold/espresso palette.
const _mutedOnDark = Color(0xFFC9B49A);
const _faintOnDark = Color(0xFF8A7860);

class FullAudioPlayerSheet extends StatelessWidget {
  final String surahNameArabic;
  final String surahNameEnglish;
  final String reciterName;
  final int currentAyah;
  final int totalAyahs;
  final bool isPlaying;
  final bool isLooping;
  final double progress;
  final String elapsedLabel;
  final String durationLabel;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onToggleLoop;
  final VoidCallback onPickReciter;

  /// Stops playback entirely and returns to the previous screen.
  final VoidCallback onBack;

  /// Leaves playback running in the background and returns to the
  /// previous screen (the mini player picks it back up).
  final VoidCallback onMinimize;

  const FullAudioPlayerSheet({
    super.key,
    required this.surahNameArabic,
    required this.surahNameEnglish,
    required this.reciterName,
    required this.currentAyah,
    required this.totalAyahs,
    required this.isPlaying,
    required this.isLooping,
    required this.progress,
    required this.elapsedLabel,
    required this.durationLabel,
    required this.onPlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onToggleLoop,
    required this.onPickReciter,
    required this.onBack,
    required this.onMinimize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.emeraldInk, AppColors.emeraldInkDark],
        ),
      ),
      child: Stack(
        children: [
          // Faint decorative arabesque backdrop — purely atmospheric,
          // very low opacity so it never competes with content.
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(painter: _ArabesquePainter()),
              ),
            ),
          ),
          // Soft glow behind the artwork disc for a premium feel.
          Positioned(
            top: 90.h,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260.w,
                height: 260.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withOpacity(0.28),
                      AppColors.gold.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 8.h),
                  _TopBar(onBack: onBack, onMinimize: onMinimize),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: onPickReciter,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.graphic_eq,
                            size: 12.sp,
                            color: AppColors.gold,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            reciterName,
                            style: AppTypography.bodyMedium.copyWith(
                              color: _mutedOnDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 28.h),
                  _ArtworkDisc(
                    surahNameArabic: surahNameArabic,
                    isPlaying: isPlaying,
                  ),
                  SizedBox(height: 26.h),
                  Text(
                    surahNameEnglish,
                    textAlign: TextAlign.center,
                    style: AppTypography.heroSerif.copyWith(
                      color: AppColors.parchment,
                      fontSize: 26.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Ayah $currentAyah of $totalAyahs',
                    style: AppTypography.bodyMedium.copyWith(
                      color: _faintOnDark,
                    ),
                  ),
                  const Spacer(),
                  _ProgressBar(
                    progress: progress,
                    elapsedLabel: elapsedLabel,
                    durationLabel: durationLabel,
                  ),
                  SizedBox(height: 22.h),
                  _Controls(
                    isPlaying: isPlaying,
                    isLooping: isLooping,
                    onPlayPause: onPlayPause,
                    onSkipNext: onSkipNext,
                    onSkipPrevious: onSkipPrevious,
                    onToggleLoop: onToggleLoop,
                    onPickReciter: onPickReciter,
                  ),
                  SizedBox(height: 28.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onMinimize;

  const _TopBar({required this.onBack, required this.onMinimize});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Stop and go back',
          onTap: onBack,
        ),
        Text(
          'NOW PLAYING',
          style: AppTypography.caption.copyWith(
            color: _faintOnDark,
            letterSpacing: 2,
          ),
        ),
        _RoundIconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          tooltip: 'Minimize — keep playing',
          onTap: onMinimize,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.06),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(9.w),
            child: Icon(icon, color: AppColors.parchment, size: 18.sp),
          ),
        ),
      ),
    );
  }
}

class _ArtworkDisc extends StatefulWidget {
  final String surahNameArabic;
  final bool isPlaying;

  const _ArtworkDisc({required this.surahNameArabic, required this.isPlaying});

  @override
  State<_ArtworkDisc> createState() => _ArtworkDiscState();
}

class _ArtworkDiscState extends State<_ArtworkDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _ArtworkDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190.w,
      height: 190.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: Container(
              width: 190.w,
              height: 190.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    AppColors.gold.withOpacity(0.05),
                    AppColors.gold,
                    AppColors.gold.withOpacity(0.05),
                  ],
                ),
              ),
              padding: EdgeInsets.all(3.w),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emeraldInk,
                ),
              ),
            ),
          ),
          Container(
            width: 158.w,
            height: 158.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.gold.withOpacity(0.16),
                  AppColors.gold.withOpacity(0.03),
                ],
              ),
              border: Border.all(color: AppColors.gold.withOpacity(0.35)),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: Text(
                  widget.surahNameArabic,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.arabicBody.copyWith(
                    fontSize: 34.sp,
                    color: AppColors.goldLight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final String elapsedLabel;
  final String durationLabel;

  const _ProgressBar({
    required this.progress,
    required this.elapsedLabel,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final thumbX = trackWidth * clamped;
            return SizedBox(
              height: 16.h,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  Container(
                    width: thumbX,
                    height: 4.h,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.amber, AppColors.gold],
                      ),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  Positioned(
                    left: (thumbX - 6.w).clamp(0.0, trackWidth - 12.w),
                    child: Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: 6.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              elapsedLabel,
              style: AppTypography.caption.copyWith(color: _faintOnDark),
            ),
            Text(
              durationLabel,
              style: AppTypography.caption.copyWith(color: _faintOnDark),
            ),
          ],
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  final bool isPlaying;
  final bool isLooping;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onToggleLoop;
  final VoidCallback onPickReciter;

  const _Controls({
    required this.isPlaying,
    required this.isLooping,
    required this.onPlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onToggleLoop,
    required this.onPickReciter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SecondaryIcon(
          icon: Icons.repeat_rounded,
          isActive: isLooping,
          onTap: onToggleLoop,
        ),
        _SkipIcon(icon: Icons.skip_previous_rounded, onTap: onSkipPrevious),
        _PlayButton(isPlaying: isPlaying, onTap: onPlayPause),
        _SkipIcon(icon: Icons.skip_next_rounded, onTap: onSkipNext),
        _SecondaryIcon(
          icon: Icons.person_search_rounded,
          isActive: false,
          onTap: onPickReciter,
        ),
      ],
    );
  }
}

class _SecondaryIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SecondaryIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.gold.withOpacity(0.16) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Icon(
            icon,
            color: isActive ? AppColors.gold : _mutedOnDark,
            size: 19.sp,
          ),
        ),
      ),
    );
  }
}

class _SkipIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SkipIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Icon(icon, color: AppColors.parchment, size: 30.sp),
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayButton({required this.isPlaying, required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 66.w,
          height: 66.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gold, AppColors.amberDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.45),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: AppColors.emeraldInkDark,
            size: 32.sp,
          ),
        ),
      ),
    );
  }
}

/// Faint, repeating eight-point star motif — a nod to traditional
/// Islamic geometric pattern work, kept extremely subtle so it reads as
/// texture rather than decoration competing with the content above it.
class _ArabesquePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 64.0;
    for (double y = -spacing; y < size.height + spacing; y += spacing) {
      for (double x = -spacing; x < size.width + spacing; x += spacing) {
        _drawStar(canvas, Offset(x, y), 18, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (math.pi / 4) * i;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArabesquePainter oldDelegate) => false;
}

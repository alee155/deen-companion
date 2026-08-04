import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// On-brand tones for text/icons that sit on the dark teal-ink background.
const _mutedOnDark = Color(0xFFB3AD9B);
const _faintOnDark = Color(0xFF7C8580);

class FullAudioPlayerSheet extends StatelessWidget {
  final String surahNameArabic;
  final String surahNameEnglish;
  final String reciterName;
  final bool isPlaying;
  final bool isLooping;
  final double progress;
  final Duration duration;
  final String elapsedLabel;
  final String durationLabel;
  final Duration? sleepTimerRemaining;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onToggleLoop;

  final ValueChanged<Duration> onSeek;
  final void Function(Duration duration) onSetSleepTimer;
  final VoidCallback onCancelSleepTimer;

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
    required this.isPlaying,
    required this.isLooping,
    required this.progress,
    required this.duration,
    required this.elapsedLabel,
    required this.durationLabel,
    required this.sleepTimerRemaining,
    required this.onPlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onToggleLoop,

    required this.onSeek,
    required this.onSetSleepTimer,
    required this.onCancelSleepTimer,
    required this.onBack,
    required this.onMinimize,
  });

  void _openSleepTimerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => _SleepTimerSheet(
        activeRemaining: sleepTimerRemaining,
        onSelect: (d) {
          Navigator.of(sheetContext).pop();
          onSetSleepTimer(d);
        },
        onTurnOff: () {
          Navigator.of(sheetContext).pop();
          onCancelSleepTimer();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
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
                      AppColors.gold.withValues(alpha: 0.28),
                      AppColors.gold.withValues(alpha: 0),
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
                  _TopBar(
                    onBack: onBack,
                    onMinimize: onMinimize,
                    sleepTimerRemaining: sleepTimerRemaining,
                    onTapSleepTimer: () => _openSleepTimerSheet(context),
                  ),
                  SizedBox(height: 6.h),
                  // GestureDetector(
                  //   onTap: {},
                  //   child: Container(
                  //     padding: EdgeInsets.symmetric(
                  //       horizontal: 12.w,
                  //       vertical: 5.h,
                  //     ),
                  //     decoration: BoxDecoration(
                  //       color: Colors.white.withValues(alpha: 0.06),
                  //       borderRadius: BorderRadius.circular(20.r),
                  //       border: Border.all(
                  //         color: AppColors.gold.withValues(alpha: 0.25),
                  //       ),
                  //     ),
                  //     child: Row(
                  //       mainAxisSize: MainAxisSize.min,
                  //       children: [
                  //         Icon(
                  //           Icons.graphic_eq,
                  //           size: 12.sp,
                  //           color: AppColors.gold,
                  //         ),
                  //         SizedBox(width: 6.w),
                  //         Text(
                  //           reciterName,
                  //           style: AppTypography.bodyMedium.copyWith(
                  //             color: _mutedOnDark,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
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
                      color: AppColors.onHeroSurface,
                      fontSize: 26.sp,
                    ),
                  ),
                  const Spacer(),
                  _ProgressBar(
                    progress: progress,
                    duration: duration,
                    elapsedLabel: elapsedLabel,
                    durationLabel: durationLabel,
                    onSeek: onSeek,
                  ),
                  SizedBox(height: 22.h),
                  _Controls(
                    isPlaying: isPlaying,
                    isLooping: isLooping,
                    onPlayPause: onPlayPause,
                    onSkipNext: onSkipNext,
                    onSkipPrevious: onSkipPrevious,
                    onToggleLoop: onToggleLoop,
                    // onPickReciter: onPickReciter,
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
  final Duration? sleepTimerRemaining;
  final VoidCallback onTapSleepTimer;

  const _TopBar({
    required this.onBack,
    required this.onMinimize,
    required this.sleepTimerRemaining,
    required this.onTapSleepTimer,
  });

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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SleepTimerButton(
              remaining: sleepTimerRemaining,
              onTap: onTapSleepTimer,
            ),
            SizedBox(width: 8.w),
            _RoundIconButton(
              icon: Icons.keyboard_arrow_down_rounded,
              tooltip: 'Minimize — keep playing',
              onTap: onMinimize,
            ),
          ],
        ),
      ],
    );
  }
}

class _SleepTimerButton extends StatelessWidget {
  final Duration? remaining;
  final VoidCallback onTap;

  const _SleepTimerButton({required this.remaining, required this.onTap});

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final active = remaining != null;
    return Tooltip(
      message: active ? 'Sleep timer running' : 'Sleep timer',
      child: Material(
        color: active
            ? AppColors.gold.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                  color: active ? AppColors.gold : AppColors.onHeroSurface,
                  size: 16.sp,
                ),
                if (active) ...[
                  SizedBox(width: 6.w),
                  Text(
                    _format(remaining!),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SleepTimerSheet extends StatelessWidget {
  final Duration? activeRemaining;
  final ValueChanged<Duration> onSelect;
  final VoidCallback onTurnOff;

  const _SleepTimerSheet({
    required this.activeRemaining,
    required this.onSelect,
    required this.onTurnOff,
  });

  static const _options = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(minutes: 60),
    Duration(minutes: 90),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 4.h),
              child: Row(
                children: [
                  Icon(
                    Icons.bedtime_outlined,
                    size: 18.sp,
                    color: AppColors.gold,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Sleep timer',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.inkText,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
              child: Text(
                'Recitation stops automatically once the time is up.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (activeRemaining != null)
              ListTile(
                leading: Icon(Icons.timer_off_outlined, color: AppColors.error),
                title: const Text('Turn off'),
                onTap: onTurnOff,
              ),
            ..._options.map(
              (d) => ListTile(
                leading: Icon(
                  Icons.nightlight_round,
                  size: 18.sp,
                  color: AppColors.textSecondary,
                ),
                title: Text('${d.inMinutes} minutes'),
                onTap: () => onSelect(d),
              ),
            ),
          ],
        ),
      ),
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
        color: Colors.white.withValues(alpha: 0.06),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(9.w),
            child: Icon(icon, color: AppColors.onHeroSurface, size: 18.sp),
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
                    AppColors.gold.withValues(alpha: 0.05),
                    AppColors.gold,
                    AppColors.gold.withValues(alpha: 0.05),
                  ],
                ),
              ),
              padding: EdgeInsets.all(3.w),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.heroSurface,
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
                  AppColors.gold.withValues(alpha: 0.16),
                  AppColors.gold.withValues(alpha: 0.03),
                ],
              ),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
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

/// Draggable seek bar. While the thumb is being dragged, the visual
/// position follows the finger directly instead of the live playback
/// stream — otherwise the position updates just as [progress] would
/// arrive from the audio engine and fight visually with the drag.
class _ProgressBar extends StatefulWidget {
  final double progress;
  final Duration duration;
  final String elapsedLabel;
  final String durationLabel;
  final ValueChanged<Duration> onSeek;

  const _ProgressBar({
    required this.progress,
    required this.duration,
    required this.elapsedLabel,
    required this.durationLabel,
    required this.onSeek,
  });

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  double get _displayValue => (_dragValue ?? widget.progress).clamp(0.0, 1.0);

  String _formatDragPosition(double value) {
    final target = widget.duration * value;
    final hours = target.inHours;
    final minutes = target.inMinutes.remainder(60).toString();
    final seconds = target.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _updateFromLocalPosition(double dx, double trackWidth) {
    if (trackWidth <= 0) return;
    final value = (dx / trackWidth).clamp(0.0, 1.0);
    setState(() => _dragValue = value);
  }

  void _commitDrag() {
    final value = _dragValue;
    if (value == null) return;
    widget.onSeek(widget.duration * value);
    setState(() => _dragValue = null);
  }

  @override
  Widget build(BuildContext context) {
    final clamped = _displayValue;
    final isDragging = _dragValue != null;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final thumbX = trackWidth * clamped;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _updateFromLocalPosition(
                details.localPosition.dx,
                trackWidth,
              ),
              onTapUp: (_) => _commitDrag(),
              onHorizontalDragStart: (details) => _updateFromLocalPosition(
                details.localPosition.dx,
                trackWidth,
              ),
              onHorizontalDragUpdate: (details) => _updateFromLocalPosition(
                details.localPosition.dx,
                trackWidth,
              ),
              onHorizontalDragEnd: (_) => _commitDrag(),
              // A slightly taller hit area than the visible 4dp track —
              // a hairline is very easy to miss with a finger otherwise.
              child: SizedBox(
                height: 28.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: isDragging ? 6.h : 4.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                    Container(
                      width: thumbX,
                      height: isDragging ? 6.h : 4.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.amber, AppColors.gold],
                        ),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                    Positioned(
                      left: (thumbX - (isDragging ? 9.w : 6.w)).clamp(
                        0.0,
                        trackWidth - (isDragging ? 18.w : 12.w),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: isDragging ? 18.w : 12.w,
                        height: isDragging ? 18.w : 12.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.6),
                              blurRadius: isDragging ? 12 : 8,
                              spreadRadius: isDragging ? 2 : 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: 2.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isDragging ? _formatDragPosition(clamped) : widget.elapsedLabel,
              style: AppTypography.caption.copyWith(
                color: isDragging ? AppColors.gold : _faintOnDark,
                fontWeight: isDragging ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            Text(
              widget.durationLabel,
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
  // final VoidCallback onPickReciter;

  const _Controls({
    required this.isPlaying,
    required this.isLooping,
    required this.onPlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onToggleLoop,
    // required this.onPickReciter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SecondaryIcon(
          icon: Icons.repeat_rounded,
          isActive: isLooping,
          onTap: onToggleLoop,
        ),
        Spacer(),
        _SkipIcon(icon: Icons.skip_previous_rounded, onTap: onSkipPrevious),
        10.w.horizontalSpace,
        _PlayButton(isPlaying: isPlaying, onTap: onPlayPause),
        10.w.horizontalSpace,
        _SkipIcon(icon: Icons.skip_next_rounded, onTap: onSkipNext),
        Spacer(),
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
      color: isActive
          ? AppColors.gold.withValues(alpha: 0.16)
          : Colors.transparent,
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
          child: Icon(icon, color: AppColors.onHeroSurface, size: 30.sp),
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gold, AppColors.amberDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45),
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

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

/// `1:05`, or `1:02:05` past an hour.
String formatPlayerTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// The progress line with its two time labels.
///
/// The line thickens and the thumb grows while it is held, and the elapsed
/// time follows the finger; the seek happens once, on release. The remaining
/// time is shown with a minus sign on the right.
class PlayerScrubber extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const PlayerScrubber({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<PlayerScrubber> createState() => _PlayerScrubberState();
}

class _PlayerScrubberState extends State<PlayerScrubber> {
  double? _drag; // 0..1 while held

  double get _fraction {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _update(double dx, double width) {
    setState(() => _drag = (dx / width).clamp(0.0, 1.0));
  }

  void _commit() {
    final f = _drag;
    setState(() => _drag = null);
    if (f == null || widget.duration == Duration.zero) return;
    widget.onSeek(
      Duration(milliseconds: (widget.duration.inMilliseconds * f).round()),
    );
  }

  static const _jump = Duration(seconds: 10);

  Duration _clamp(Duration d) => d < Duration.zero
      ? Duration.zero
      : (d > widget.duration ? widget.duration : d);

  void _nudge(Duration by) => widget.onSeek(_clamp(widget.position + by));

  @override
  Widget build(BuildContext context) {
    final holding = _drag != null;
    final fraction = _drag ?? _fraction;
    final shown = holding
        ? Duration(
            milliseconds: (widget.duration.inMilliseconds * fraction).round(),
          )
        : widget.position;
    final remaining = widget.duration - shown;

    final labelStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.onHeroSurface.withValues(alpha: holding ? 0.95 : 0.6),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Semantics(
      slider: true,
      // The times below are read once, as the slider's value, not again.
      excludeSemantics: true,
      label: 'Playback position',
      value:
          '${formatPlayerTime(shown)} of ${formatPlayerTime(widget.duration)}',
      // What a screen reader announces after a 10-second swipe up or down.
      increasedValue: formatPlayerTime(_clamp(shown + _jump)),
      decreasedValue: formatPlayerTime(_clamp(shown - _jump)),
      onIncrease: () => _nudge(_jump),
      onDecrease: () => _nudge(-_jump),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  _update(d.localPosition.dx, width);
                  _commit();
                },
                onHorizontalDragStart: (d) =>
                    _update(d.localPosition.dx, width),
                onHorizontalDragUpdate: (d) =>
                    _update(d.localPosition.dx, width),
                onHorizontalDragEnd: (_) => _commit(),
                onHorizontalDragCancel: () => setState(() => _drag = null),
                child: SizedBox(
                  height: 30.h,
                  child: Center(
                    child: _Track(fraction: fraction, thick: holding),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatPlayerTime(shown), style: labelStyle),
              Text(
                '-${formatPlayerTime(remaining < Duration.zero ? Duration.zero : remaining)}',
                style: labelStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Track extends StatelessWidget {
  final double fraction;
  final bool thick;
  const _Track({required this.fraction, required this.thick});

  @override
  Widget build(BuildContext context) {
    final height = thick ? 9.0 : 5.0;
    final thumb = thick ? 18.0 : 11.0;
    return LayoutBuilder(
      builder: (context, box) {
        final filled = box.maxWidth * fraction;
        return SizedBox(
          height: thumb,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: height,
                width: filled,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.gold, AppColors.amber],
                  ),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              // The pearl.
              Positioned(
                left: (filled - thumb / 2).clamp(0.0, box.maxWidth - thumb),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: thumb,
                  height: thumb,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldLight,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import 'mihrab_artwork.dart';

/// The player docked above the navigation bar: a floating capsule with the
/// surah in a small mihrab, play/pause, next, and close. Tapping it opens the
/// full player; a thin line along its bottom edge shows progress.
class MiniPlayerBar extends StatelessWidget {
  final String title;
  final String titleArabic;
  final String subtitle;
  final bool isPlaying;
  final double progress; // 0.0–1.0
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onClose;

  const MiniPlayerBar({
    super.key,
    required this.title,
    required this.titleArabic,
    required this.subtitle,
    required this.isPlaying,
    required this.progress,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
    required this.onClose,
  });

  Widget _action(IconData icon, String label, VoidCallback onTap, double size) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: label,
      scale: AppMotion.pressScaleSmall,
      child: Padding(
        padding: EdgeInsets.all(7.w),
        child: IconSwap(
          child: Icon(
            icon,
            key: ValueKey(icon),
            size: size.sp,
            color: AppColors.onHeroSurface,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Open player, $title',
      behavior: HitTestBehavior.deferToChild,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1713),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 9.h, 6.w, 12.h),
              child: Row(
                children: [
                  _Thumb(titleArabic: titleArabic),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onHeroSurface,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: AppColors.goldLight.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _action(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    isPlaying ? 'Pause' : 'Play',
                    onPlayPause,
                    30,
                  ),
                  _action(Icons.skip_next_rounded, 'Next surah', onNext, 28),
                  _action(Icons.close_rounded, 'Stop playback', onClose, 18),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 3.h,
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.08)),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.gold, AppColors.amber],
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small mihrab with the surah's name: the same artwork as the full player,
/// without the pattern.
class _Thumb extends StatelessWidget {
  final String titleArabic;
  const _Thumb({required this.titleArabic});

  @override
  Widget build(BuildContext context) {
    final w = 38.w;
    final h = MihrabArtwork.heightFor(w) * 0.95;
    final size = Size(w, h);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          ClipPath(
            clipper: _ThumbClipper(),
            child: SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF1B1511), AppColors.amberDeep],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: h * 0.3, left: 2, right: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      titleArabic,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'AmiriQuran',
                        fontSize: 15.sp,
                        height: 1.3,
                        color: AppColors.onHeroSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(size: size, painter: _ThumbOutline(size)),
          ),
        ],
      ),
    );
  }
}

class _ThumbClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => mihrabPath(size);

  @override
  bool shouldReclip(_ThumbClipper old) => false;
}

class _ThumbOutline extends CustomPainter {
  final Size size_;
  _ThumbOutline(this.size_);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      mihrabPath(size_, inset: 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.gold.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_ThumbOutline old) => old.size_ != size_;
}

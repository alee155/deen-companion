import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

const _ink = Color(0xFF1A1A1A);

/// Previous, back 10 s, play/pause, forward 10 s, next.
///
/// The 10-second jumps are here because recitation is long and a missed phrase
/// is common; they sit beside the play button, where the thumb already is.
class PlayerTransport extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onBack10;
  final VoidCallback onForward10;

  const PlayerTransport({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onBack10,
    required this.onForward10,
  });

  Widget _icon(IconData icon, String label, VoidCallback onTap, double size) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: label,
      scale: AppMotion.pressScaleSmall,
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Icon(icon, size: size.sp, color: AppColors.onHeroSurface),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _icon(Icons.skip_previous_rounded, 'Previous surah', onPrevious, 36),
        _icon(Icons.replay_10_rounded, 'Back 10 seconds', onBack10, 32),
        Pressable(
          onTap: onPlayPause,
          haptic: true,
          semanticLabel: isPlaying ? 'Pause' : 'Play',
          child: Container(
            width: 74.w,
            height: 74.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onHeroSurface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.32),
                  blurRadius: 30,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconSwap(
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(isPlaying),
                size: 40.sp,
                color: _ink,
              ),
            ),
          ),
        ),
        _icon(Icons.forward_10_rounded, 'Forward 10 seconds', onForward10, 32),
        _icon(Icons.skip_next_rounded, 'Next surah', onNext, 36),
      ],
    );
  }
}

/// A rounded button with an icon and a label, lit up when its setting is on.
class PlayerPill extends StatelessWidget {
  final IconData? icon;

  /// Text shown instead of, or beside, the icon (for example `1.25×`).
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String semanticLabel;

  const PlayerPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    required this.semanticLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tint = active ? AppColors.goldLight : AppColors.onHeroSurface;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        haptic: true,
        semanticLabel: semanticLabel,
        scale: AppMotion.pressScaleSmall,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 44.h,
          decoration: BoxDecoration(
            color: active
                ? AppColors.amber.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: active
                  ? AppColors.amber.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17.sp, color: tint),
                SizedBox(width: 6.w),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round glass button for the title row.
class PlayerRoundButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;
  const PlayerRoundButton({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      scale: AppMotion.pressScaleSmall,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

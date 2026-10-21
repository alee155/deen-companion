import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';

/// Shared shell for the group bottom sheets: a hero-style header (same
/// gradient + geometric pattern as the Group / Prayer Times screens) over a
/// parchment body. [destructive] shifts the header toward red.
class GroupSheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final Widget child;

  const GroupSheetFrame({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final from = destructive
        ? Color.lerp(AppColors.heroSurface, AppColors.error, 0.62)!
        : AppColors.heroSurface;
    final to = destructive
        ? Color.lerp(AppColors.emeraldInkDark, AppColors.error, 0.35)!
        : AppColors.emeraldInkDark;
    final accent = destructive ? Colors.white : AppColors.emeraldInk;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      child: ColoredBox(
        color: AppColors.parchment,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [from, to],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GeometricPattern(
                          color: accent.withValues(alpha: 0.09),
                          cell: 48,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20.w, 10.h, 12.w, 18.h),
                        child: Column(
                          children: [
                            Container(
                              width: 38.w,
                              height: 4.h,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),
                            SizedBox(height: 14.h),
                            Row(
                              children: [
                                SizedBox(
                                  width: 52.w,
                                  height: 52.w,
                                  child: CustomPaint(
                                    painter: StarPainter(
                                      fill: accent.withValues(alpha: 0.18),
                                      stroke: accent,
                                      strokeWidth: 1.4,
                                      inner: 0.76,
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 23.sp,
                                      color: accent,
                                    ),
                                  ),
                                ).slideIn(RevealDirection.start, distance: 14),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child:
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 19.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            subtitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              height: 1.35,
                                              color: AppColors.onHeroSurface
                                                  .withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ],
                                      ).slideIn(
                                        RevealDirection.bottomStart,
                                        delay: const Duration(milliseconds: 50),
                                        distance: 10,
                                      ),
                                ),
                                IconButton(
                                  tooltip: 'Close',
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showGroupSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

/// Inline error / success notice that animates in and out.
class SheetNotice extends StatelessWidget {
  final String? message;
  final bool success;

  const SheetNotice({super.key, required this.message, this.success = false});

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.success : AppColors.error;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      success
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 18.sp,
                      color: color,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        message!,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          height: 1.35,
                          color: AppColors.inkText,
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

/// Primary / destructive filled button with an in-place spinner.
class SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;
  final IconData? icon;

  const SheetButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = destructive ? AppColors.error : AppColors.emeraldInk;
    final fg = destructive ? Colors.white : AppColors.onEmeraldInk;
    return SizedBox(
      height: 50.h,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: loading ? bg : bg.withValues(alpha: 0.32),
          disabledForegroundColor: loading ? fg : fg.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: loading
              ? SizedBox(
                  key: const ValueKey('spin'),
                  height: 20.h,
                  width: 20.h,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : FittedBox(
                  key: const ValueKey('label'),
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18.sp),
                        SizedBox(width: 8.w),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class SheetSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SheetSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50.h,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? null : Icon(icon, size: 18.sp),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkText,
          side: BorderSide(color: AppColors.borderWarm, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
          ),
        ),
      ),
    );
  }
}

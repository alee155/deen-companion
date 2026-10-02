import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../prayer_dnd/presentation/providers/prayer_dnd_provider.dart';

/// Settings entry for "Do Not Disturb during prayer": the same ink-to-orange
/// hero treatment as the feature's own screen, with the live state (on/off
/// and how many prayers are set up) readable without opening it.
class DndSettingsTile extends ConsumerWidget {
  final VoidCallback onTap;
  const DndSettingsTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dndSettingsProvider);
    final on = settings.enabled;
    final count = settings.configuredCount;

    final subtitle = !on
        ? 'Silence your phone automatically while you pray.'
        : count == 0
        ? 'On — choose how long for each prayer.'
        : 'On for $count ${count == 1 ? 'prayer' : 'prayers'}.';

    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
          ),
          borderRadius: BorderRadius.circular(22.r),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: GeometricPattern(
                color: AppColors.goldLight.withValues(alpha: 0.07),
                cell: 44,
              ),
            ),
            Positioned(
              right: -14.w,
              bottom: -22.h,
              child: Icon(
                Icons.do_not_disturb_on_rounded,
                size: 120.sp,
                color: AppColors.gold.withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14.w),
              child: Row(
                children: [
                  Container(
                    width: 46.w,
                    height: 46.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      Icons.do_not_disturb_on_rounded,
                      size: 24.sp,
                      color: AppColors.goldLight,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Do Not Disturb during prayer',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        AnimatedText(
                          subtitle,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            height: 1.35,
                            color: AppColors.onHeroSurface.withValues(
                              alpha: 0.78,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: context.motion.duration(AppMotion.normal),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: on
                              ? AppColors.emeraldInk
                              : Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          on ? 'ON' : 'OFF',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                            color: on
                                ? AppColors.onEmeraldInk
                                : Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18.sp,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';

/// iOS counterpart of the Android "Do Not Disturb during prayer" tile.
///
/// iOS doesn't let an app switch a Focus on or off, so there is nothing to
/// toggle: the tile opens a short guide to setting the phone up to go quiet at
/// prayer times by itself, in the same hero style as the Android tile.
class PrayerSilenceGuideTile extends StatelessWidget {
  const PrayerSilenceGuideTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => showPrayerSilenceGuide(context),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradient,
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
                          'Silence your phone during prayer',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          'iPhone can’t do this for an app, but a Focus can. '
                          'Set it up in a minute.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18.sp,
                    color: Colors.white.withValues(alpha: 0.8),
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

Future<void> showPrayerSilenceGuide(BuildContext context) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _PrayerSilenceGuideSheet(),
  );
}

class _PrayerSilenceGuideSheet extends StatelessWidget {
  const _PrayerSilenceGuideSheet();

  static const _steps = [
    ('Create a Focus', 'Settings > Focus > + > Custom, and name it “Prayer”.'),
    (
      'Schedule it',
      'Add Schedule > Time, and pick a window around your prayers. They move '
          'a little each day, so leave some room.',
    ),
    (
      'Or use Shortcuts',
      'Shortcuts > Automation > Time of Day, then “Set Focus” at each prayer '
          'time.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.parchment,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22.w, 12.h, 22.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.borderWarm,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'Silence your phone during prayer',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Apple doesn’t let apps switch Do Not Disturb on. On iPhone, set '
                'a Focus once and it does the work.',
                style: TextStyle(
                  fontSize: 13.sp,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 18.h),
              for (var i = 0; i < _steps.length; i++)
                _Step(number: i + 1, title: _steps[i].$1, body: _steps[i].$2),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.toolsAccentBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.alarm_on_rounded,
                      size: 18.sp,
                      color: AppColors.toolsAccent,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'Your prayer alarm still rings during any Focus, so '
                        'you won’t miss the adhan.',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          height: 1.4,
                          color: AppColors.inkText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emeraldInk,
                    foregroundColor: AppColors.onEmeraldInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  const _Step({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.emeraldInk,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.onEmeraldInk,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

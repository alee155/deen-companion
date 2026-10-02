import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/screens/settings_screen.dart';
import '../providers/prayer_calculation_settings_provider.dart';
import '../providers/prayer_times_provider.dart';
import 'calculation_settings_sheets.dart';

void showPrayerSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _PrayerSettingsSheet(),
  );
}

class _PrayerSettingsSheet extends ConsumerWidget {
  const _PrayerSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(prayerCalculationSettingsProvider);

    Widget tile(IconData icon, String title, String value, VoidCallback onTap) {
      return ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 2.h),
        leading: Container(
          padding: EdgeInsets.all(9.w),
          decoration: BoxDecoration(
            color: AppColors.toolsAccentBg,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, size: 20.sp, color: AppColors.toolsAccent),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ),
        subtitle: value.isEmpty
            ? null
            : Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      );
    }

    // Material (not a decorated Container) so the ListTiles' ink and
    // background paint on this surface instead of being hidden behind it.
    return Material(
      color: AppColors.parchment,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.borderWarm,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 6.h),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Prayer settings',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
              ),
            ),
            tile(
              Icons.calculate_rounded,
              'Calculation method',
              s.method.label,
              () => showCalculationMethodPicker(context, ref),
            ),
            tile(
              Icons.wb_sunny_rounded,
              'Asr school',
              s.school.label,
              () => showAsrSchoolPicker(context, ref),
            ),
            tile(
              Icons.notifications_active_rounded,
              'Prayer reminders',
              'Adhan and alerts for each prayer',
              () {
                Navigator.of(context).pop();
                context.push('/reminders');
              },
            ),
            tile(
              Icons.do_not_disturb_on_rounded,
              'Do Not Disturb',
              'Silence your phone during prayer',
              () {
                Navigator.of(context).pop();
                context.push('/prayer-dnd');
              },
            ),
            tile(Icons.my_location_rounded, 'Refresh location & times', '', () {
              Navigator.of(context).pop();
              ref.read(prayerTimesNotifierProvider.notifier).refresh();
            }),
            tile(Icons.settings_rounded, 'All app settings', '', () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }
}

import '../../../../core/device/platform_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/screens/settings_screen.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../providers/manual_city_provider.dart';
import '../providers/prayer_calculation_settings_provider.dart';
import '../providers/prayer_times_provider.dart';
import 'calculation_settings_sheets.dart';

void showPrayerSettingsSheet(BuildContext context) {
  showGroupSheet<void>(context, (_) => const _PrayerSettingsSheet());
}

class _PrayerSettingsSheet extends ConsumerWidget {
  const _PrayerSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(prayerCalculationSettingsProvider);

    Widget tile(IconData icon, String title, String value, VoidCallback onTap) {
      return ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 2.h),
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

    return GroupSheetFrame(
      icon: Icons.tune_rounded,
      title: 'Prayer settings',
      subtitle: 'Calculation, location and reminders in one place.',
      pinHeader: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            Icons.location_city_rounded,
            'Location',
            ref.watch(manualCityProvider)?.label ??
                'Using your device location',
            () {
              Navigator.of(context).pop();
              context.push('/prayer-times/city');
            },
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
          if (PlatformSupport.prayerDnd)
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
        ],
      ),
    );
  }
}

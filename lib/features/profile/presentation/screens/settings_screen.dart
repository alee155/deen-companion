import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_info/app_info_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../islamic_calendar/presentation/providers/hijri_adjustment_provider.dart';
import '../../../islamic_calendar/presentation/widgets/hijri_fine_tune_row.dart';
import '../../../daily_content/debug/daily_content_debug_panel.dart';
import '../../../daily_content/presentation/providers/daily_content_providers.dart';
import '../../../prayer_reminders/debug/prayer_alarm_debug_harness.dart';
import '../../../prayer_reminders/presentation/providers/reminders_provider.dart';
import '../../../prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import '../../../prayer_times/presentation/widgets/calculation_settings_sheets.dart';
import '../widgets/dnd_settings_tile.dart';
import '../widgets/settings_about_card.dart';
import '../widgets/settings_bento_tile.dart';
import '../widgets/settings_option_chip.dart';
import '../widgets/settings_section_label.dart';
import '../widgets/settings_theme_split.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClearCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      animationStyle: AppMotion.dialogStyle,
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.r),
        ),
        title: Text(
          'Clear cached content?',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This clears locally cached Quran, Hadith and Dua content so the '
          "app re-downloads fresh copies. Your Favorites and Recent Activity "
          "are kept.",
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Clear',
              style: TextStyle(
                color: AppColors.emeraldInk,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref
        .read(localStorageServiceProvider)
        .clearAll(AppConstants.apiCacheBoxName);

    if (!context.mounted) return;
    _snack(context, 'Cached content cleared');
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.inkText,
          margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      _snack(context, 'Could not open the link. Please check your connection.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeChoice = ref.watch(themeModeNotifierProvider);
    final calcSettings = ref.watch(prayerCalculationSettingsProvider);
    final remindersOn = ref.watch(remindersEnabledProvider);
    final hijriAdjustment = ref.watch(hijriAdjustmentProvider);
    final dailyContentOn = ref.watch(dailyNotificationEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 120.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.inkText,
                ),
              ).slideIn(RevealDirection.topStart),
              SizedBox(height: 12.h),

              const SettingsSectionLabel('APPEARANCE').slideIn(
                RevealDirection.start,
                delay: const Duration(milliseconds: 70),
                distance: 12,
              ),
              SizedBox(height: 12.h),
              SettingsThemeSplit(
                isDark: themeChoice == AppThemeChoice.dark,
                onChanged: (dark) => ref
                    .read(themeModeNotifierProvider.notifier)
                    .setChoice(
                      dark ? AppThemeChoice.dark : AppThemeChoice.light,
                    ),
              ),
              SizedBox(height: 30.h),

              const SettingsSectionLabel('PRAYER TIMES').slideIn(
                RevealDirection.bottomStart,
                onVisible: true,
                duration: AppMotion.normal,
                distance: 16,
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 158.h,
                child: Row(
                  children: [
                    Expanded(
                      child:
                          SettingsBentoTile(
                            color: AppColors.inkText,
                            onTap: () => context.push('/reminders'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  color: AppColors.onEmeraldInk.withValues(
                                    alpha: 0.7,
                                  ),
                                  size: 24.sp,
                                ),
                                const Spacer(),
                                Text(
                                  'Prayer Reminders',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.onEmeraldInk.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      remindersOn ? 'On' : 'Off',
                                      style: TextStyle(
                                        fontSize: 32.sp,
                                        fontWeight: FontWeight.w900,
                                        color: remindersOn
                                            ? AppColors.emeraldInk
                                            : AppColors.onEmeraldInk.withValues(
                                                alpha: 0.4,
                                              ),
                                        height: 1.0,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: AppColors.onEmeraldInk.withValues(
                                        alpha: 0.6,
                                      ),
                                      size: 20.sp,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ).slideIn(
                            RevealDirection.start,
                            onVisible: true,
                            distance: 20,
                          ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child:
                          SettingsBentoTile(
                            color: AppColors.surfaceLight,
                            bordered: true,
                            onTap: () =>
                                showCalculationMethodPicker(context, ref),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Calculation Method',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Expanded(
                                  child: Text(
                                    calcSettings.method.label,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.inkText,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Icon(
                                    Icons.unfold_more_rounded,
                                    color: AppColors.textMuted,
                                    size: 20.sp,
                                  ),
                                ),
                              ],
                            ),
                          ).slideIn(
                            RevealDirection.end,
                            onVisible: true,
                            distance: 20,
                            delay: const Duration(milliseconds: 60),
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              SettingsBentoTile(
                color: AppColors.emeraldInk,
                onTap: () => showAsrSchoolPicker(context, ref),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asr Juristic School',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.onEmeraldInk.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            calcSettings.school.label,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w900,
                              color: AppColors.onEmeraldInk,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.onEmeraldInk,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ).slideIn(RevealDirection.bottom, onVisible: true),
              SizedBox(height: 12.h),
              DndSettingsTile(
                onTap: () => context.push('/prayer-dnd'),
              ).slideIn(RevealDirection.bottomEnd, onVisible: true),
              SizedBox(height: 30.h),

              const SettingsSectionLabel('ISLAMIC CALENDAR').slideIn(
                RevealDirection.topStart,
                onVisible: true,
                duration: AppMotion.normal,
                distance: 16,
              ),
              SizedBox(height: 12.h),
              SettingsBentoTile(
                color: AppColors.surfaceLight,
                bordered: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hijri date adjustment',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        Expanded(
                          child: SettingsOptionChip(
                            label: 'Automatic',
                            selected: hijriAdjustment == 0,
                            onTap: () => ref
                                .read(hijriAdjustmentProvider.notifier)
                                .setAutomatic(),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: SettingsOptionChip(
                            label: 'Pakistan',
                            selected: hijriAdjustment == -1,
                            onTap: () => ref
                                .read(hijriAdjustmentProvider.notifier)
                                .setPakistan(),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    const HijriFineTuneRow(),
                    SizedBox(height: 14.h),
                    Text(
                      'Pakistan uses the moon-sighting announcement, which can '
                      'differ from the calculated date by a day or two. '
                      'Fine-tune it to match your local calendar.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ).slideIn(RevealDirection.bottomStart, onVisible: true),
              SizedBox(height: 30.h),

              const SettingsSectionLabel('DAILY CONTENT').slideIn(
                RevealDirection.bottomStart,
                onVisible: true,
                duration: AppMotion.normal,
                distance: 16,
              ),
              SizedBox(height: 12.h),
              SettingsBentoTile(
                color: Colors.transparent,
                bordered: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ayat & Hadith of the Day',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkText,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'A daily notification about 20 minutes after Fajr.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: dailyContentOn,
                      activeThumbColor: AppColors.emeraldInk,
                      onChanged: (v) => ref
                          .read(dailyNotificationEnabledProvider.notifier)
                          .set(v),
                    ),
                  ],
                ),
              ).slideIn(RevealDirection.bottomEnd, onVisible: true),
              SizedBox(height: 30.h),

              const SettingsSectionLabel('DATA & STORAGE').slideIn(
                RevealDirection.bottomStart,
                onVisible: true,
                duration: AppMotion.normal,
                distance: 16,
              ),
              SizedBox(height: 12.h),
              SettingsBentoTile(
                color: Colors.transparent,
                bordered: true,
                onTap: () => _confirmClearCache(context, ref),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Clear cached content',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkText,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Favorites & recent activity are kept.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.delete_sweep_outlined,
                      color: AppColors.textSecondary,
                      size: 24.sp,
                    ),
                  ],
                ),
              ).slideIn(RevealDirection.bottomEnd, onVisible: true),
              SizedBox(height: 30.h),

              const SettingsSectionLabel('ABOUT'),
              SizedBox(height: 12.h),
              SettingsAboutCard(
                version: ref
                    .watch(appDisplayVersionProvider)
                    .when(
                      data: (v) => v,
                      loading: () => '…',
                      error: (_, _) => '—',
                    ),
                onPrivacy: () =>
                    _openLink(context, AppConstants.privacyPolicyUrl),
                onTerms: () =>
                    _openLink(context, AppConstants.termsAndConditionsUrl),
              ),
              // SizedBox(height: 26.h),

              // const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),
              // SizedBox(height: 26.h),
              if (kDebugMode) ...[
                SizedBox(height: 20.h),
                const PrayerAlarmDebugHarness(),
                SizedBox(height: 12.h),
                const DailyContentDebugPanel(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

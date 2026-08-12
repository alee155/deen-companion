import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_info/app_info_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../shared/widgets/grouped_settings_tile.dart';
import '../../../islamic_calendar/presentation/providers/hijri_adjustment_provider.dart';
import '../../../prayer_reminders/debug/prayer_alarm_debug_harness.dart';
import '../../../prayer_reminders/presentation/providers/reminders_provider.dart';
import '../../../prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import '../../../prayer_times/presentation/widgets/calculation_settings_sheets.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClearCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Clear cached content?',
          style: AppTypography.headline.copyWith(
            color: AppColors.inkText,
            fontSize: 16.sp,
          ),
        ),
        content: Text(
          "This clears locally cached Quran, Hadith, and Dua content so the "
          "app re-downloads fresh copies. Your Favorites and Recent Activity "
          "are kept.",
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
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
                color: AppColors.hadithAccent,
                fontWeight: FontWeight.w700,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.emeraldInk,
        content: Text(
          'Cached content cleared',
          style: TextStyle(color: AppColors.surfaceLight),
        ),
      ),
    );
  }

  Future<void> _openLegalUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.hadithAccent,
          content: Text(
            'Could not open the link. Please check your connection.',
            style: TextStyle(color: AppColors.surfaceLight),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: const DeenAppBar(title: 'Settings'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
        children: [
          const _HeaderCard().appear(),

          const GroupedSectionLabel(
            'Appearance',
          ).appear(delay: Duration(milliseconds: 60)),
          _ThemeModeSelector(
            selected: mode,
            onChanged: (choice) =>
                ref.read(themeModeNotifierProvider.notifier).setChoice(choice),
          ).appear(delay: const Duration(milliseconds: 90)),

          const GroupedSectionLabel(
            'Prayer Times',
          ).appear(delay: const Duration(milliseconds: 105)),
          Builder(
            builder: (context) {
              final calcSettings = ref.watch(prayerCalculationSettingsProvider);
              final remindersOn = ref.watch(remindersEnabledProvider);
              return GroupedCard(
                children: [
                  GroupedTile(
                    icon: Icons.notifications_active_outlined,
                    iconColor: AppColors.worshipAccent,
                    iconBg: AppColors.worshipAccentBg,
                    title: 'Prayer Reminders',
                    subtitle: remindersOn ? 'On' : 'Off',
                    onTap: () => context.push('/reminders'),
                  ),
                  GroupedTile(
                    icon: Icons.calculate_outlined,
                    iconColor: AppColors.hijriAccent,
                    iconBg: AppColors.hijriAccentBg,
                    title: 'Calculation Method',
                    subtitle: calcSettings.method.label,
                    onTap: () => showCalculationMethodPicker(context, ref),
                  ),
                  GroupedTile(
                    icon: Icons.mosque_outlined,
                    iconColor: AppColors.emeraldInk,
                    iconBg: AppColors.gold.withValues(alpha: 0.15),
                    title: 'Asr Juristic School',
                    subtitle: calcSettings.school.label,
                    onTap: () => showAsrSchoolPicker(context, ref),
                  ),
                ],
              );
            },
          ).appear(delay: const Duration(milliseconds: 118)),
          SizedBox(height: 24.h),

          const GroupedSectionLabel(
            'Islamic Calendar',
          ).appear(delay: const Duration(milliseconds: 120)),
          Builder(
            builder: (context) {
              final adjustment = ref.watch(hijriAdjustmentProvider);
              return _HijriAdjustmentSelector(
                selected: adjustment,
                onChanged: (days) async {
                  final notifier = ref.read(hijriAdjustmentProvider.notifier);
                  if (days == -1) {
                    await notifier.setPakistan();
                  } else {
                    await notifier.setAutomatic();
                  }
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.emeraldInk,
                      content: Text(
                        'Applied',
                        style: TextStyle(color: AppColors.surfaceLight),
                      ),
                    ),
                  );
                },
              );
            },
          ).appear(delay: const Duration(milliseconds: 128)),
          Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: Text(
              'Automatic shows the Hijri date exactly as calculated; '
              '"Pakistan (−1 Day)" always shows one day earlier, matching '
              'the date observed in Pakistan. We pick a starting default '
              'for you based on your region the first time the app needs '
              'this you can change it here anytime, and it applies '
              'immediately.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ).appear(delay: const Duration(milliseconds: 132)),

          const GroupedSectionLabel(
            'Data & Storage',
          ).appear(delay: const Duration(milliseconds: 120)),
          GroupedCard(
            children: [
              GroupedTile(
                icon: Icons.cleaning_services_outlined,
                iconColor: AppColors.toolsAccent,
                iconBg: AppColors.toolsAccentBg,
                title: 'Clear cached content',
                subtitle: 'Favorites & recent activity are kept',
                onTap: () => _confirmClearCache(context, ref),
              ),
            ],
          ).appear(delay: const Duration(milliseconds: 150)),
          SizedBox(height: 24.h),

          const GroupedSectionLabel(
            'About',
          ).appear(delay: const Duration(milliseconds: 180)),
          GroupedCard(
            children: [
              GroupedTile(
                icon: Icons.ios_share_outlined,
                iconColor: AppColors.quranAccent,
                iconBg: AppColors.quranAccentBg,
                title: 'Share Deen Companion',
                subtitle: 'Tell a friend or family member',
                onTap: () => Share.share(
                  'I\'ve been using Deen Companion for Quran, Hadith, '
                  'prayer times and more — thought you might like it too.',
                ),
              ),
              GroupedTile(
                icon: Icons.shield_outlined,
                iconColor: AppColors.hijriAccent,
                iconBg: AppColors.hijriAccentBg,
                title: 'Privacy Policy',
                onTap: () =>
                    _openLegalUrl(context, AppConstants.privacyPolicyUrl),
              ),
              GroupedTile(
                icon: Icons.description_outlined,
                iconColor: AppColors.duasAccent,
                iconBg: AppColors.duasAccentBg,
                title: 'Terms & Conditions',
                onTap: () =>
                    _openLegalUrl(context, AppConstants.termsAndConditionsUrl),
              ),
              GroupedTile(
                icon: Icons.info_outline,
                iconColor: AppColors.worshipAccent,
                iconBg: AppColors.worshipAccentBg,
                title: 'Version',
                trailingText: ref
                    .watch(appDisplayVersionProvider)
                    .when(
                      data: (version) => version,
                      loading: () => '…',
                      error: (_, _) => '—',
                    ),
                showChevron: false,
              ),
            ],
          ).appear(delay: const Duration(milliseconds: 210)),
          const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),

          SizedBox(height: 16.h),
          Center(
            child: Text(
              'Made for the Ummah 🤍',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ).appear(delay: const Duration(milliseconds: 240)),

          if (kDebugMode) ...[
            SizedBox(height: 24.h),
            const PrayerAlarmDebugHarness(),
          ],
        ],
      ),
    );
  }
}

// ── Header ──

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.emeraldInk, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.mosque_outlined,
              color: AppColors.gold,
              size: 26.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: AppTypography.greetingSerif.copyWith(
                    color: AppColors.surfaceLight,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Your companion for daily worship',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.goldLight,
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

// ── Hijri adjustment selector — same visual language as the theme picker ──

class _HijriAdjustmentSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _HijriAdjustmentSelector({
    required this.selected,
    required this.onChanged,
  });

  static const _options = [
    (days: 0, label: 'Automatic'),
    (days: -1, label: 'Pakistan (−1 Day)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: _options.map((option) {
          final isSelected = option.days == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option.days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.emeraldInk : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isSelected
                        ? AppColors.surfaceLight
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Theme selector — three tappable cards instead of the stock SegmentedButton ──

class _ThemeModeSelector extends StatelessWidget {
  final AppThemeChoice selected;
  final ValueChanged<AppThemeChoice> onChanged;

  const _ThemeModeSelector({required this.selected, required this.onChanged});

  // Two choices only — the app no longer follows the system setting, it
  // opens in Light and remembers whatever the user picks here.
  static const _options = [
    (
      mode: AppThemeChoice.light,
      icon: Icons.light_mode_outlined,
      label: 'Light',
    ),
    (mode: AppThemeChoice.dark, icon: Icons.dark_mode_outlined, label: 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: _options.map((option) {
          final isSelected = option.mode == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option.mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.emeraldInk : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    Icon(
                      option.icon,
                      size: 20.sp,
                      color: isSelected
                          ? AppColors.gold
                          : AppColors.textSecondary,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      option.label,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isSelected
                            ? AppColors.surfaceLight
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../shared/widgets/grouped_settings_tile.dart';
import '../../../prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import '../../../prayer_times/presentation/widgets/calculation_settings_sheets.dart';
import '../widgets/legal_content.dart';
import 'legal_text_screen.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
        children: [
          const _HeaderCard().appear(),

          const GroupedSectionLabel(
            'Appearance',
          ).appear(delay: const Duration(milliseconds: 60)),
          _ThemeModeSelector(
            selected: mode,
            onChanged: (m) =>
                ref.read(themeModeNotifierProvider.notifier).setMode(m),
          ).appear(delay: const Duration(milliseconds: 90)),
          SizedBox(height: 24.h),

          const GroupedSectionLabel(
            'Prayer Times',
          ).appear(delay: const Duration(milliseconds: 105)),
          Builder(
            builder: (context) {
              final calcSettings = ref.watch(prayerCalculationSettingsProvider);
              return GroupedCard(
                children: [
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
                    iconBg: AppColors.gold.withOpacity(0.15),
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LegalTextScreen(
                      title: 'Privacy Policy',
                      updatedLabel:
                          'A summary of how Deen Companion handles your data.',
                      sections: LegalContent.privacySections,
                    ),
                  ),
                ),
              ),
              GroupedTile(
                icon: Icons.description_outlined,
                iconColor: AppColors.duasAccent,
                iconBg: AppColors.duasAccentBg,
                title: 'Terms & Conditions',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const LegalTextScreen(
                      title: 'Terms & Conditions',
                      updatedLabel:
                          'A summary of the terms for using Deen Companion.',
                      sections: LegalContent.termsSections,
                    ),
                  ),
                ),
              ),
              GroupedTile(
                icon: Icons.info_outline,
                iconColor: AppColors.worshipAccent,
                iconBg: AppColors.worshipAccentBg,
                title: 'Version',
                trailingText: AppConstants.appVersion,
                showChevron: false,
              ),
            ],
          ).appear(delay: const Duration(milliseconds: 210)),

          SizedBox(height: 16.h),
          Center(
            child: Text(
              'Made for the Ummah 🤍',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ).appear(delay: const Duration(milliseconds: 240)),
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
              color: AppColors.gold.withOpacity(0.18),
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

// ── Theme selector — three tappable cards instead of the stock SegmentedButton ──

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeSelector({required this.selected, required this.onChanged});

  static const _options = [
    (
      mode: ThemeMode.system,
      icon: Icons.brightness_auto_outlined,
      label: 'System',
    ),
    (mode: ThemeMode.light, icon: Icons.light_mode_outlined, label: 'Light'),
    (mode: ThemeMode.dark, icon: Icons.dark_mode_outlined, label: 'Dark'),
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

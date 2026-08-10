import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/grouped_settings_tile.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesCount =
        ref.watch(favoritesNotifierProvider).valueOrNull?.length ?? 0;
    final recentCount =
        ref.watch(recentActivityNotifierProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            const _ProfileHeaderCard().appear(),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.favorite_outline,
                    iconColor: AppColors.hadithAccent,
                    iconBg: AppColors.hadithAccentBg,
                    value: '$favoritesCount',
                    label: 'Favorites',
                    onTap: () => context.go('/favorites'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _StatCard(
                    icon: Icons.history,
                    iconColor: AppColors.quranAccent,
                    iconBg: AppColors.quranAccentBg,
                    value: '$recentCount',
                    label: 'Recent',
                    onTap: () => context.go('/recent-activity'),
                  ),
                ),
              ],
            ).appear(delay: const Duration(milliseconds: 60)),
            SizedBox(height: 24.h),

            const GroupedSectionLabel(
              'Your Library',
            ).appear(delay: const Duration(milliseconds: 100)),
            GroupedCard(
              children: [
                GroupedTile(
                  icon: Icons.favorite_outline,
                  iconColor: AppColors.hadithAccent,
                  iconBg: AppColors.hadithAccentBg,
                  title: 'Favorites',
                  subtitle: favoritesCount == 0
                      ? 'Nothing saved yet'
                      : '$favoritesCount saved item${favoritesCount == 1 ? '' : 's'}',
                  onTap: () => context.go('/favorites'),
                ),
                GroupedTile(
                  icon: Icons.history,
                  iconColor: AppColors.quranAccent,
                  iconBg: AppColors.quranAccentBg,
                  title: 'Recent Activity',
                  subtitle: recentCount == 0
                      ? 'Nothing viewed yet'
                      : 'Your last $recentCount activit${recentCount == 1 ? 'y' : 'ies'}',
                  onTap: () => context.go('/recent-activity'),
                ),
              ],
            ).appear(delay: const Duration(milliseconds: 130)),
            SizedBox(height: 24.h),

            const GroupedSectionLabel(
              'Preferences',
            ).appear(delay: const Duration(milliseconds: 160)),
            GroupedCard(
              children: [
                GroupedTile(
                  icon: Icons.settings_outlined,
                  iconColor: AppColors.toolsAccent,
                  iconBg: AppColors.toolsAccentBg,
                  title: 'Settings',
                  subtitle: 'Appearance, storage, and about',
                  onTap: () => context.push('/profile/settings'),
                ),
              ],
            ).appear(delay: const Duration(milliseconds: 190)),

            SizedBox(height: 16.h),
            Center(
              child: Text(
                '${AppConstants.appName} · v${AppConstants.appVersion}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ).appear(delay: const Duration(milliseconds: 220)),
            SizedBox(height: 16.h),
            const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),
          ],
        ),
      ),
    );
  }
}

// ── Header ──

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: [
          Container(
            width: 58.w,
            height: 58.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.emeraldInk, AppColors.emeraldInkDark],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              color: AppColors.gold,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: AppTypography.greetingSerif.copyWith(
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'No account needed — everything stays on this device',
                  style: AppTypography.bodyMedium.copyWith(
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

// ── Stat card ──

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Icon(icon, color: iconColor, size: 16.sp),
              ),
              SizedBox(height: 10.h),
              Text(
                value,
                style: AppTypography.headline.copyWith(
                  color: AppColors.inkText,
                  fontSize: 20.sp,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

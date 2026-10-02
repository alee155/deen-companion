import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_info/app_info_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/grouped_settings_tile.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../widgets/guest_benefits_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stat_tile.dart';
import '../widgets/profile_streak_card.dart';

/// Profile tab. Adapts to the auth state: guests get a sign-in prompt and
/// what an account adds; signed-in users get their streak, group stats and
/// account actions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      animationStyle: AppMotion.dialogStyle,
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.parchment,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Text(
          'Log out?',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ),
        content: Text(
          'You’ll go back to browsing as a guest. Favorites and settings on this device are kept.',
          style: TextStyle(
            fontSize: 13.sp,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.heroSurface,
              foregroundColor: AppColors.goldLight,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    HapticFeedback.mediumImpact();
    await ref.read(authSessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final signedIn = session.isAuthenticated;
    final favoritesCount =
        ref.watch(favoritesNotifierProvider).valueOrNull?.length ?? 0;
    final recentCount =
        ref.watch(recentActivityNotifierProvider).valueOrNull?.length ?? 0;
    final groups = ref.watch(myGroupsProvider).valueOrNull ?? const [];
    final owned = ref.watch(ownedGroupsCountProvider);

    const dirs = [
      RevealDirection.bottom,
      RevealDirection.bottomStart,
      RevealDirection.topStart, // 2 label
      RevealDirection.bottomEnd, // 3 card
      RevealDirection.bottomStart, // 4 label
      RevealDirection.bottom, // 5 card
      RevealDirection.topStart, // 6 label
      RevealDirection.bottomEnd, // 7 card
      RevealDirection.bottomStart, // 8 label
      RevealDirection.bottom, // 9 card
    ];
    Widget stagger(Widget child, int i) => child.slideIn(
      dirs[i],
      delay: Duration(milliseconds: 40 * i),
      distance: 18,
      onVisible: true,
    );

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            ProfileHeader(session: session),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 130.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (signedIn) ...[
                    ref
                        .watch(myStreakStatsProvider)
                        .when(
                          data: (s) => stagger(ProfileStreakCard(stats: s), 0),
                          loading: () => SizedBox(height: 190.h),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child:
                              ProfileStatTile(
                                icon: Icons.workspace_premium_rounded,
                                color: AppColors.gold,
                                bg: AppColors.gold.withValues(alpha: 0.16),
                                value: '$owned',
                                label: owned == 1
                                    ? 'Group created'
                                    : 'Groups created',
                                onTap: () => context.go('/groups'),
                              ).slideIn(
                                RevealDirection.bottomStart,
                                delay: const Duration(milliseconds: 40),
                                distance: 18,
                              ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child:
                              ProfileStatTile(
                                icon: Icons.groups_rounded,
                                color: AppColors.worshipAccent,
                                bg: AppColors.worshipAccentBg,
                                value: '${groups.length}',
                                label: groups.length == 1
                                    ? 'Group joined'
                                    : 'Groups joined',
                                onTap: () => context.go('/groups'),
                              ).slideIn(
                                RevealDirection.bottomEnd,
                                delay: const Duration(milliseconds: 80),
                                distance: 18,
                              ),
                        ),
                      ],
                    ),
                  ] else
                    stagger(const GuestBenefitsCard(), 0),
                  SizedBox(height: 24.h),

                  stagger(const GroupedSectionLabel('Your library'), 2),
                  stagger(
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
                          title: 'Recent activity',
                          subtitle: recentCount == 0
                              ? 'Nothing viewed yet'
                              : 'Your last $recentCount activit${recentCount == 1 ? 'y' : 'ies'}',
                          onTap: () => context.push('/recent-activity'),
                        ),
                      ],
                    ),
                    3,
                  ),
                  SizedBox(height: 24.h),

                  stagger(const GroupedSectionLabel('Community'), 4),
                  stagger(
                    GroupedCard(
                      children: [
                        GroupedTile(
                          icon: Icons.groups_rounded,
                          iconColor: AppColors.worshipAccent,
                          iconBg: AppColors.worshipAccentBg,
                          title: 'My groups',
                          subtitle: groups.isEmpty
                              ? 'Create or join a Quran group'
                              : '${groups.length} group${groups.length == 1 ? '' : 's'} · $owned created by you',
                          onTap: () => context.go('/groups'),
                        ),
                      ],
                    ),
                    5,
                  ),
                  SizedBox(height: 24.h),

                  stagger(const GroupedSectionLabel('Preferences'), 6),
                  stagger(
                    GroupedCard(
                      children: [
                        GroupedTile(
                          icon: Icons.settings_outlined,
                          iconColor: AppColors.toolsAccent,
                          iconBg: AppColors.toolsAccentBg,
                          title: 'Settings',
                          subtitle:
                              'Appearance, prayer alerts, storage and about',
                          onTap: () => context.go('/settings'),
                        ),
                      ],
                    ),
                    7,
                  ),

                  if (signedIn) ...[
                    SizedBox(height: 24.h),
                    stagger(const GroupedSectionLabel('Account'), 8),
                    // Reset password and Delete account are UI-only for now:
                    // no onTap / navigation until their flows are decided.
                    stagger(
                      GroupedCard(
                        children: [
                          GroupedTile(
                            icon: Icons.lock_reset_rounded,
                            iconColor: AppColors.toolsAccent,
                            iconBg: AppColors.toolsAccentBg,
                            title: 'Reset password',
                            forceChevron: true,
                          ),
                          GroupedTile(
                            icon: Icons.delete_outline_rounded,
                            iconColor: AppColors.error,
                            iconBg: AppColors.hadithAccentBg,
                            title: 'Delete account',
                            titleColor: AppColors.error,
                            forceChevron: true,
                          ),
                          GroupedTile(
                            icon: Icons.logout_rounded,
                            iconColor: AppColors.textSecondary,
                            iconBg: AppColors.parchment,
                            title: 'Log out',
                            showChevron: false,
                            onTap: () => _confirmLogout(context, ref),
                          ),
                        ],
                      ),
                      9,
                    ),
                  ],

                  SizedBox(height: 20.h),
                  Center(
                    child: Text(
                      ref
                          .watch(appVersionNameProvider)
                          .when(
                            data: (v) => '${AppConstants.appName} · v$v',
                            loading: () => AppConstants.appName,
                            error: (_, _) => AppConstants.appName,
                          ),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ).slideIn(RevealDirection.top, onVisible: true, distance: 14),
                  const BannerAdWidget(
                    margin: EdgeInsets.symmetric(vertical: 4),
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

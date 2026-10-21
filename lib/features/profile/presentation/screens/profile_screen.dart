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
import '../../../auth/presentation/providers/delete_account_controller.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/guest_benefits_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_shortcut_tile.dart';
import '../widgets/profile_stats_strip.dart';

/// Profile tab. Adapts to the auth state: guests get a sign-in prompt and
/// what an account adds; signed-in users get their figures, shortcuts and
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      animationStyle: AppMotion.dialogStyle,
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.parchment,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Text(
          'Delete account?',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ),
        content: Text(
          'This permanently deletes your account and can’t be undone. '
          'Favorites and settings on this device are kept.',
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
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await ref
        .read(deleteAccountControllerProvider.notifier)
        .delete();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Your account has been deleted.'
              : ref.read(deleteAccountControllerProvider).errorMessage ??
                    'Couldn’t delete your account. Try again.',
        ),
      ),
    );
  }

  static String _fmt(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

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
    // Reading the profile also mirrors the latest name and picture into the
    // session the header shows (and keeps the server timezone current).
    if (signedIn) ref.watch(profileProvider);
    final points = signedIn ? ref.watch(myPointsProvider).valueOrNull : null;

    Widget reveal(Widget child, int i) => child.slideIn(
      i.isEven ? RevealDirection.bottomStart : RevealDirection.bottomEnd,
      delay: Duration(milliseconds: 40 * i),
      distance: 18,
      onVisible: true,
    );

    // The strip straddles the header edge: half of it hangs below.
    final overlap = signedIn ? ProfileStatsStrip.height.h / 2 : 0.0;

    final shortcuts = [
      ProfileShortcutTile(
        icon: Icons.favorite_rounded,
        color: AppColors.hadithAccent,
        bg: AppColors.hadithAccentBg,
        title: 'Favorites',
        subtitle: favoritesCount == 0
            ? 'Nothing saved yet'
            : '$favoritesCount saved',
        onTap: () => context.go('/favorites'),
      ),
      ProfileShortcutTile(
        icon: Icons.history_rounded,
        color: AppColors.quranAccent,
        bg: AppColors.quranAccentBg,
        title: 'Recent',
        subtitle: recentCount == 0
            ? 'Nothing viewed yet'
            : 'Last $recentCount viewed',
        onTap: () => context.push('/recent-activity'),
      ),
      ProfileShortcutTile(
        icon: Icons.groups_rounded,
        color: AppColors.worshipAccent,
        bg: AppColors.worshipAccentBg,
        title: 'My groups',
        subtitle: groups.isEmpty
            ? 'Create or join one'
            : '${groups.length} joined · $owned yours',
        onTap: () => context.go('/groups'),
      ),
      ProfileShortcutTile(
        icon: Icons.stars_rounded,
        color: AppColors.gold,
        bg: AppColors.gold.withValues(alpha: 0.16),
        title: 'My points',
        subtitle: points == null
            ? 'How points work'
            : '${_fmt(points.total)} earned',
        onTap: () => context.push('/points-rules'),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ProfileHeader(session: session, bottomOverlap: overlap),
                if (signedIn)
                  Positioned(
                    left: 20.w,
                    right: 20.w,
                    bottom: -overlap,
                    child:
                        ProfileStatsStrip(
                          stats: [
                            ProfileStat(
                              label: 'Points',
                              value: points?.total ?? 0,
                              icon: Icons.stars_rounded,
                            ),
                            ProfileStat(
                              label: 'Joined',
                              value: groups.length,
                              icon: Icons.groups_rounded,
                            ),
                            ProfileStat(
                              label: 'Created',
                              value: owned,
                              icon: Icons.workspace_premium_rounded,
                            ),
                          ],
                        ).slideIn(
                          RevealDirection.bottom,
                          delay: const Duration(milliseconds: 240),
                          distance: 18,
                        ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, overlap + 22.h, 20.w, 130.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!signedIn) ...[
                    reveal(const GuestBenefitsCard(), 0),
                    SizedBox(height: 24.h),
                  ],
                  reveal(const GroupedSectionLabel('Shortcuts'), 1),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    // A fixed height (not an aspect ratio) so larger system
                    // text can't overflow the tile.
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12.w,
                      crossAxisSpacing: 12.w,
                      mainAxisExtent: 140.h,
                    ),
                    children: [
                      for (var i = 0; i < shortcuts.length; i++)
                        reveal(shortcuts[i], i + 2),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  reveal(const GroupedSectionLabel('More'), 6),
                  reveal(
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
                        if (signedIn)
                          GroupedTile(
                            icon: Icons.lock_reset_rounded,
                            iconColor: AppColors.toolsAccent,
                            iconBg: AppColors.toolsAccentBg,
                            title: 'Reset password',
                            forceChevron: true,
                            onTap: () => context.push(
                              '/forgot-password'
                              '?email=${Uri.encodeQueryComponent(session.email ?? '')}',
                            ),
                          ),
                      ],
                    ),
                    7,
                  ),
                  if (signedIn) ...[
                    SizedBox(height: 24.h),
                    reveal(
                      GroupedCard(
                        children: [
                          GroupedTile(
                            icon: Icons.logout_rounded,
                            iconColor: AppColors.textSecondary,
                            iconBg: AppColors.parchment,
                            title: 'Log out',
                            showChevron: false,
                            onTap: () => _confirmLogout(context, ref),
                          ),
                          GroupedTile(
                            icon: Icons.delete_outline_rounded,
                            iconColor: AppColors.error,
                            iconBg: AppColors.hadithAccentBg,
                            title: 'Delete account',
                            titleColor: AppColors.error,
                            forceChevron: true,
                            onTap: () => _confirmDelete(context, ref),
                          ),
                        ],
                      ),
                      8,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

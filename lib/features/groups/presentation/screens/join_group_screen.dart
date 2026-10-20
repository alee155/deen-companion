import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../domain/entities/invite_preview.dart';
import '../../domain/invite_link.dart';
import '../providers/groups_providers.dart';
import '../widgets/group_sheet_widgets.dart';

/// Landing screen for a group invite link. Joining only happens here, in the
/// app: the backend's web page for the link just forwards people to it.
///
/// Guests are sent to log in / sign up first and come straight back here.
class JoinGroupScreen extends ConsumerWidget {
  final String token;
  const JoinGroupScreen({super.key, required this.token});

  String get _self => InviteLink.routeFor(token);

  void _toGroups(BuildContext context) => context.go('/groups');

  /// Opens the group with the Groups tab underneath, so Back lands there.
  void _openGroup(BuildContext context, String groupId) {
    context.go('/groups');
    context.push('/groups/$groupId');
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final name = ref.read(invitePreviewProvider(token)).valueOrNull?.groupName;
    final result = await ref
        .read(joinGroupControllerProvider.notifier)
        .join(token);
    if (result == null || !context.mounted) return;
    _openGroup(context, result.groupId);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          result.alreadyMember
              ? 'You’re already in ${name ?? 'this group'}'
              : 'You joined ${name ?? 'the group'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invitePreviewProvider(token));
    final signedIn = ref.watch(
      authSessionProvider.select((s) => s.isAuthenticated),
    );

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            _Header(onClose: () => _toGroups(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 28.h),
                child: async.when(
                  loading: () => ShimmerBox(
                    width: double.infinity,
                    height: 220.h,
                    borderRadius: 24.r,
                  ),
                  error: (e, _) => _InvalidInvite(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(invitePreviewProvider(token)),
                    onClose: () => _toGroups(context),
                  ),
                  data: (p) => _Preview(
                    preview: p,
                    signedIn: signedIn,
                    onOpen: () => _openGroup(context, p.groupId!),
                    onJoin: () => _join(context, ref),
                    onLogin: () => context.push(
                      '/login?redirect=${Uri.encodeQueryComponent(_self)}',
                    ),
                    onSignup: () => context.push(
                      '/signup?redirect=${Uri.encodeQueryComponent(_self)}',
                    ),
                    onClose: () => _toGroups(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.emeraldInk.withValues(alpha: 0.08),
              cell: 52,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20.w,
              MediaQuery.of(context).padding.top + 8.h,
              12.w,
              24.h,
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                  ),
                ),
                SizedBox(
                  width: 72.w,
                  height: 72.w,
                  child: CustomPaint(
                    painter: StarPainter(
                      fill: AppColors.emeraldInk.withValues(alpha: 0.18),
                      stroke: AppColors.emeraldInk,
                      strokeWidth: 1.5,
                      inner: 0.76,
                    ),
                    child: Icon(
                      Icons.group_add_rounded,
                      size: 32.sp,
                      color: AppColors.emeraldInk,
                    ),
                  ),
                ).slideIn(RevealDirection.bottom),
                SizedBox(height: 12.h),
                Text(
                  'You’re invited',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ).slideIn(
                  RevealDirection.top,
                  delay: const Duration(milliseconds: 60),
                  distance: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final InvitePreview preview;
  final bool signedIn;
  final VoidCallback onOpen;
  final VoidCallback onJoin;
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onClose;

  const _Preview({
    required this.preview,
    required this.signedIn,
    required this.onOpen,
    required this.onJoin,
    required this.onLogin,
    required this.onSignup,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final p = preview;
    final canOpen = p.isMember && p.groupId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Column(
            children: [
              Text(
                'Join',
                style: TextStyle(
                  fontSize: 12.sp,
                  letterSpacing: 1,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                p.groupName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkText,
                ),
              ),
              if (p.description.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  p.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: 14.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.worshipAccentBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_alt_rounded,
                      size: 15.sp,
                      color: AppColors.worshipAccent,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '${p.memberCount} ${p.memberCount == 1 ? 'member' : 'members'}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.worshipAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).slideIn(RevealDirection.bottom, distance: 14),
        SizedBox(height: 18.h),
        if (canOpen) ...[
          Text(
            'You’re already a member of this group.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 12.h),
          SheetButton(
            label: 'Open group',
            icon: Icons.arrow_forward_rounded,
            onPressed: onOpen,
          ),
        ] else if (!signedIn) ...[
          Text(
            'Log in or create an account to join this group.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 12.h),
          SheetButton(
            label: 'Log in to join',
            icon: Icons.login_rounded,
            onPressed: onLogin,
          ),
          SizedBox(height: 10.h),
          SheetSecondaryButton(label: 'Create an account', onPressed: onSignup),
        ] else
          _JoinAction(onJoin: onJoin),
        SizedBox(height: 10.h),
        if (!signedIn || canOpen)
          const SizedBox.shrink()
        else
          Center(
            child: TextButton(
              onPressed: onClose,
              child: Text(
                'Not now',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
      ],
    );
  }
}

/// Join button + inline error, driven by [joinGroupControllerProvider].
class _JoinAction extends ConsumerWidget {
  final VoidCallback onJoin;
  const _JoinAction({required this.onJoin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(joinGroupControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetNotice(message: state.errorMessage),
        SheetButton(
          label: 'Join group',
          icon: Icons.group_add_rounded,
          loading: state.isJoining,
          onPressed: onJoin,
        ),
      ],
    );
  }
}

class _InvalidInvite extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _InvalidInvite({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Column(
            children: [
              Icon(Icons.link_off_rounded, size: 36.sp, color: AppColors.error),
              SizedBox(height: 10.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.4,
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Ask a group member for a fresh link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        SheetButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
        SizedBox(height: 10.h),
        SheetSecondaryButton(label: 'Back to groups', onPressed: onClose),
      ],
    );
  }
}

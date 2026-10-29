import '../../../prayer_logs/domain/prayer_log.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_detail.dart';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return DateFormat('d MMM').format(t);
}

String joinedLabel(DateTime? t) =>
    t == null ? '' : 'Joined ${DateFormat('d MMM yyyy').format(t.toLocal())}';

class RoleBadge extends StatelessWidget {
  final GroupRole role;
  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final admin = role == GroupRole.admin;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: admin
            ? AppColors.emeraldInk.withValues(alpha: 0.18)
            : AppColors.worshipAccentBg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        admin ? 'ADMIN' : 'MEMBER',
        style: TextStyle(
          fontSize: 8.5.sp,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          color: AppColors.worshipAccent,
        ),
      ),
    );
  }
}

/// The member's picture, or their initials when they have none. A gold ring means the member has snapped today.
class MemberAvatar extends StatelessWidget {
  final GroupMember member;
  final double size;
  final bool ring;

  const MemberAvatar({
    super.key,
    required this.member,
    required this.size,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = member.avatarUrl;
    final initials = Text(
      member.initials,
      style: TextStyle(
        fontSize: size * 0.32,
        fontWeight: FontWeight.w800,
        color: AppColors.worshipAccent,
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ring ? AppColors.emeraldInk : AppColors.borderWarm,
          width: 1.8,
        ),
      ),
      child: Container(
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.worshipAccentBg,
        ),
        child: url == null
            ? initials
            : CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Shows the initials while loading and if the link fails.
                placeholder: (_, _) => initials,
                errorWidget: (_, _, _) => initials,
                fadeInDuration: const Duration(milliseconds: 150),
              ),
      ),
    );
  }
}

/// Where the app keeps the two snap icons.
const snapPendingAsset = 'assets/images/snap_pending.png';
const snapViewedAsset = 'assets/images/snap_viewed.png';

/// A member's snap on their card. Unopened: a filled arrow, tap to view it
/// full screen (once). Opened: the outlined arrow, nothing to tap. Expired: the
/// same, dimmed. No snap: the outlined arrow. Never active on the viewer's own
/// card, which has nothing to open.
class SnapBox extends StatelessWidget {
  final SnapState state;
  final VoidCallback? onTap;
  final double size;

  const SnapBox({
    super.key,
    this.state = SnapState.none,
    required this.onTap,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = state == SnapState.unopened && onTap != null;
    final box = size.w;
    final label = switch (state) {
      SnapState.unopened => 'View snap',
      SnapState.opened => 'Snap already opened',
      SnapState.expired => 'Snap expired',
      SnapState.none => 'No snap',
    };
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: box * 0.8,
        child: Opacity(
          opacity: state == SnapState.expired ? 0.4 : 1,
          child: SizedBox(
            width: box,
            height: box,
            child: Padding(
              padding: EdgeInsets.all(box * 0.12),
              child: Image.asset(
                enabled ? snapPendingAsset : snapViewedAsset,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

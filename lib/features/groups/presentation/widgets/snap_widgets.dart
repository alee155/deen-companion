import 'dart:math' as math;
import '../../../prayer_logs/presentation/widgets/snap_photo_viewer.dart';
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

/// Marks sections that currently show sample numbers (the snap statistics
/// API isn't live yet).
class PreviewBadge extends StatelessWidget {
  const PreviewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.worshipAccentBg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        'SAMPLE DATA',
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

/// Initials avatar. A gold ring means the member has snapped today.
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.worshipAccentBg,
        ),
        child: Text(
          member.initials,
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w800,
            color: AppColors.worshipAccent,
          ),
        ),
      ),
    );
  }
}

/// A member's snap on their card. With a photo it shows that photo as a small
/// picture inside a green ring (like an unseen story), and tapping opens it
/// full screen. Without one (or on the viewer's own card) it is a plain white
/// box and does nothing.
class SnapBox extends StatelessWidget {
  final bool hasPhoto;
  final VoidCallback? onTap;
  final double size;

  /// The photo to preview. Nothing is loaded when null.
  final String? photoUrl;

  const SnapBox({
    super.key,
    required this.hasPhoto,
    required this.onTap,
    this.size = 36,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = hasPhoto && onTap != null;
    final box = size.w;
    final radius = box * 0.3;
    final preview = enabled && photoUrl != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? 'View photo' : 'No photo',
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: box * 0.8,
        child: Container(
          width: box,
          height: box,
          padding: EdgeInsets.all(preview ? 2.w : 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: enabled ? AppColors.emeraldInk : AppColors.borderWarm,
              width: enabled ? 1.8 : 1,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.emeraldInk.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: preview
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(radius - 2.w),
                  child: SnapPhoto(url: photoUrl!),
                )
              : null,
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

/// Bars of snaps per day, oldest → newest; today is highlighted.
class ActivityBarChart extends StatelessWidget {
  final List<int> values;
  final double height;

  const ActivityBarChart({super.key, required this.values, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final first = today.subtract(Duration(days: values.length - 1));
    return Semantics(
      label:
          'Snap activity over the last ${values.length} days, '
          '${values.fold<int>(0, (a, b) => a + b)} snaps in total',
      child: Column(
        children: [
          SizedBox(
            height: height.h,
            width: double.infinity,
            child: CustomPaint(
              painter: _BarsPainter(
                values: values,
                bar: AppColors.emeraldInk.withValues(alpha: 0.45),
                highlight: AppColors.emeraldInk,
                grid: AppColors.borderWarm,
                label: AppColors.textMuted,
                labelSize: 9.sp,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('d MMM').format(first),
                style: TextStyle(fontSize: 10.sp, color: AppColors.textMuted),
              ),
              Text(
                'Today',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<int> values;
  final Color bar;
  final Color highlight;
  final Color grid;
  final Color label;
  final double labelSize;

  _BarsPainter({
    required this.values,
    required this.bar,
    required this.highlight,
    required this.grid,
    required this.label,
    required this.labelSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = math.max(values.reduce(math.max), 1);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final slot = size.width / values.length;
    final barW = slot * 0.56;
    for (var i = 0; i < values.length; i++) {
      final h = size.height * (values[i] / maxV) * 0.94;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          i * slot + (slot - barW) / 2,
          size.height - math.max(h, values[i] == 0 ? 2 : 0),
          barW,
          math.max(h, values[i] == 0 ? 2 : 0),
        ),
        topLeft: Radius.circular(barW / 2),
        topRight: Radius.circular(barW / 2),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = i == values.length - 1 ? highlight : bar,
      );
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '$maxV',
        style: TextStyle(fontSize: labelSize, color: label),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(2, 2));
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values || old.bar != bar || old.highlight != highlight;
}

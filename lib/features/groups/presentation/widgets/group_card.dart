import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../group_live/presentation/providers/group_live_store.dart';
import '../../../prayer_logs/domain/group_member_prayers.dart';
import '../../../prayer_logs/domain/prayer_log.dart';
import '../../../prayer_logs/presentation/prayer_labels.dart';
import '../../domain/entities/group.dart';
import 'group_image.dart';

/// One group in the Home list: the picture in an accent ring, the name, the
/// latest thing a member did today, and on the right the group's best streak
/// and how many have prayed. Rows sit on the page, separated by a thin line
/// (the list draws it), not in boxes.
///
/// The numbers and the latest activity come from the same live data the group
/// screen uses, so they move as members log prayers. Until the numbers arrive
/// the row shows just the member count.
class GroupCard extends ConsumerWidget {
  final Group group;
  final VoidCallback onTap;

  const GroupCard({super.key, required this.group, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numbers = ref.watch(
      groupLiveProvider(group.id).select((s) => s.summary?.group),
    );
    final me = ref.watch(authSessionProvider.select((s) => s.userId));
    final feed = ref.watch(liveGroupFeedProvider(group.id));
    final activity = latestGroupActivity(feed, me: me, now: DateTime.now());

    return PressScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.emeraldInk, width: 2),
                ),
                child: GroupImage(
                  path: group.imagePath,
                  size: 52.w,
                  radius: 26.w,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      activity ?? _quietLine(numbers == null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (numbers != null) ...[
                SizedBox(width: 10.w),
                _Trailing(
                  streak: numbers.topCurrentStreak,
                  line:
                      '${numbers.goalMetCount} of ${numbers.memberCount} prayed',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// What the second line says when nobody has logged anything today.
  String _quietLine(bool loading) => loading
      ? '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}'
      : 'No prayers logged yet today';
}

class _Trailing extends StatelessWidget {
  final int streak;
  final String line;
  const _Trailing({required this.streak, required this.line});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 20.sp,
              color: AppColors.emeraldInk,
            ),
            SizedBox(width: 2.w),
            AnimatedCount(
              value: streak,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.emeraldInk,
              ),
            ),
          ],
        ),
        SizedBox(height: 3.h),
        Text(
          line,
          style: TextStyle(fontSize: 12.5.sp, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// "Hamza snapped Asr · 1m": the newest log in today's feed, or null when
/// there is none (or the feed has not loaded). [me] is shown as "You".
String? latestGroupActivity(
  List<GroupMemberPrayers>? feed, {
  required String? me,
  required DateTime now,
}) {
  if (feed == null) return null;
  GroupMemberPrayers? who;
  PrayerLog? newest;
  for (final member in feed) {
    for (final log in member.logs) {
      if (newest == null || log.loggedAt.isAfter(newest.loggedAt)) {
        newest = log;
        who = member;
      }
    }
  }
  if (newest == null || who == null) return null;
  final name = who.userId == me ? 'You' : who.displayName.split(' ').first;
  final verb = newest.snapState(now) == SnapState.none ? 'prayed' : 'snapped';
  return '$name $verb ${newest.prayer.label} · ${shortAgo(now.difference(newest.loggedAt))}';
}

/// `now`, `5m`, `2h`, `3d`: how long ago, in the fewest characters.
String shortAgo(Duration d) {
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  return '${d.inDays}d';
}

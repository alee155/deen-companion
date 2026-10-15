import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/group_member_prayers.dart';
import '../prayer_labels.dart';
import '../providers/prayer_logs_providers.dart';
import 'snap_photo_viewer.dart';

/// Group detail: who has prayed what today. Members only — the server
/// answers 403 to anyone else, shown as a plain message.
class GroupPrayersSection extends ConsumerWidget {
  final String groupId;
  const GroupPrayersSection({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (groupId: groupId, date: null as String?);
    final feed = ref.watch(groupPrayersProvider(key));
    final myId = ref.watch(authSessionProvider).userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Row(
            children: [
              Icon(
                Icons.mosque_rounded,
                size: 18.sp,
                color: AppColors.emeraldInk,
              ),
              SizedBox(width: 8.w),
              Text(
                'Today’s prayers',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkText,
                ),
              ),
            ],
          ),
        ),
        feed.when(
          data: (members) => _Card(members: members, myId: myId),
          loading: () => ShimmerBox(
            width: double.infinity,
            height: 150.h,
            borderRadius: 24.r,
          ),
          error: (e, _) => Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: _decoration(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    e is Failure
                        ? prayerLogErrorMessage(e)
                        : 'Couldn’t load today’s prayers.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(groupPrayersProvider(key)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static BoxDecoration _decoration() => BoxDecoration(
    color: AppColors.surfaceLight,
    borderRadius: BorderRadius.circular(24.r),
    border: Border.all(color: AppColors.borderWarm),
  );
}

class _Card extends StatelessWidget {
  final List<GroupMemberPrayers> members;
  final String? myId;
  const _Card({required this.members, required this.myId});

  @override
  Widget build(BuildContext context) {
    // Most prayers first; ties keep the server's order.
    final sorted = [...members]
      ..sort((a, b) => b.loggedCount.compareTo(a.loggedCount));

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: GroupPrayersSection._decoration(),
      child: sorted.isEmpty
          ? Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'No members yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  _MemberRow(member: sorted[i], isMe: sorted[i].userId == myId),
                  if (i != sorted.length - 1)
                    Divider(height: 1, color: AppColors.borderWarm),
                ],
              ],
            ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final GroupMemberPrayers member;
  final bool isMe;
  const _MemberRow({required this.member, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18.r,
            backgroundColor: AppColors.worshipAccentBg,
            child: Text(
              member.initials,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.worshipAccent,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${member.displayName} (you)' : member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  member.loggedCount == 0
                      ? 'Nothing yet'
                      : '${member.loggedCount} of 5 · ${member.totalPoints} pts',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          for (final p in PrayerName.values) ...[
            SizedBox(width: 5.w),
            _Dot(member: member, prayer: p),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final GroupMemberPrayers member;
  final PrayerName prayer;
  const _Dot({required this.member, required this.prayer});

  @override
  Widget build(BuildContext context) {
    final log = member.logFor(prayer);
    final done = log != null;
    final url = log?.snapUrl;
    return Semantics(
      label: '${prayer.label} ${done ? 'logged' : 'not logged'}',
      child: GestureDetector(
        onTap: url == null
            ? null
            : () => showSnapPhoto(
                context,
                url: url,
                title: '${member.displayName} · ${prayer.label}',
              ),
        child: Container(
          width: 22.w,
          height: 22.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.emeraldInk : Colors.transparent,
            border: Border.all(
              color: done ? AppColors.emeraldInk : AppColors.borderWarm,
              width: 1.4,
            ),
          ),
          child: done
              ? Icon(
                  Icons.check_rounded,
                  size: 13.sp,
                  color: AppColors.onEmeraldInk,
                )
              : null,
        ),
      ),
    );
  }
}

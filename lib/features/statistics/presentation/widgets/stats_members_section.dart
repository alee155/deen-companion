import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/bars_model.dart';
import '../../domain/entities/group_stats.dart';
import '../providers/chart_providers.dart';
import '../providers/statistics_providers.dart';

/// Why a member is flagged for the admin, in a few words.
String attentionText(AttentionMember m) => [
  for (final f in m.flags)
    switch (f) {
      AttentionFlag.neverLogged => 'Never logged a prayer',
      AttentionFlag.inactive =>
        m.daysSinceLastLog == null
            ? 'Inactive'
            : 'Inactive for ${m.daysSinceLastLog} days',
      AttentionFlag.declining => 'Declining',
    },
].join(' · ');

/// The members, as on the group screen: one card, a row each. Tap a member to
/// show their days on the chart. For the admin, a member who has gone quiet or
/// is slipping says so under their name.
class StatsMembersSection extends ConsumerWidget {
  final String groupId;
  final String? myId;
  final bool isAdmin;

  /// Called after a member is chosen (the screen scrolls the chart into view).
  final VoidCallback onChosen;

  const StatsMembersSection({
    super.key,
    required this.groupId,
    required this.myId,
    required this.isAdmin,
    required this.onChosen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(
      memberRowsProvider((groupId: groupId, isAdmin: isAdmin)),
    );
    final subject = ref.watch(statsSubjectProvider);

    return rows.when(
      loading: () =>
          ShimmerBox(width: double.infinity, height: 200.h, borderRadius: 24.r),
      error: (e, _) => FailureView(
        failure: failureFrom(e),
        compact: true,
        onRetry: () async => ref.invalidate(groupMemberStatsProvider(groupId)),
      ),
      data: (data) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.borderWarm),
        ),
        child: Column(
          children: [
            for (final (i, r) in data.indexed) ...[
              _Row(
                data: r,
                isMe: r.stat.userId == myId,
                selected:
                    subject is MemberSubject && subject.userId == r.stat.userId,
                onTap: () {
                  HapticFeedback.selectionClick();
                  // You have your own pill; picking yourself shows that.
                  ref
                      .read(statsSubjectProvider.notifier)
                      .state = r.stat.userId == myId
                      ? StatsSubject.me
                      : MemberSubject(r.stat.userId);
                  onChosen();
                },
              ),
              if (i != data.length - 1)
                Divider(height: 1, indent: 60.w, color: AppColors.borderWarm),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final MemberRowData data;
  final bool isMe;
  final bool selected;
  final VoidCallback onTap;

  const _Row({
    required this.data,
    required this.isMe,
    required this.selected,
    required this.onTap,
  });

  String get _initials {
    final parts = data.stat.displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final m = data.stat;
    final pct = m.completionPercent;
    final flag = data.attention;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${m.displayName}${isMe ? ', you' : ''}. Show on the chart.'
          '${flag == null ? '' : ' Needs attention: ${attentionText(flag)}.'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: selected ? AppColors.gold.withValues(alpha: 0.12) : null,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.worshipAccentBg,
                  border: Border.all(
                    color: selected ? AppColors.gold : AppColors.borderWarm,
                    width: selected ? 2 : 1.8,
                  ),
                ),
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.worshipAccent,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? '${m.displayName} (you)' : m.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${m.points} pts · '
                      '${pct == null ? 'no completion yet' : '${pct.round()}% complete'}',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (flag != null) ...[
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            size: 12.sp,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              attentionText(flag),
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.local_fire_department_rounded,
                size: 14.sp,
                color: m.currentStreak > 0
                    ? AppColors.amber
                    : AppColors.textMuted,
              ),
              SizedBox(width: 2.w),
              Text(
                '${m.currentStreak}d',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                selected
                    ? Icons.show_chart_rounded
                    : Icons.chevron_right_rounded,
                size: 20.sp,
                color: selected ? AppColors.amberDeep : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../groups/domain/entities/group_detail.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../../../groups/presentation/widgets/snap_widgets.dart';
import '../providers/snap_providers.dart';

/// Step 4: who gets the snap. Everyone in the group is always included and
/// the list is read-only — there is deliberately nothing to toggle.
class RecipientsView extends ConsumerWidget {
  final String groupId;
  final VoidCallback onBack;

  /// Called with every recipient id when the user taps Send.
  final void Function(List<String> recipientIds) onSend;

  const RecipientsView({
    super.key,
    required this.groupId,
    required this.onBack,
    required this.onSend,
  });

  static String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composer = ref.watch(snapComposerProvider(groupId));
    final detailAsync = ref.watch(groupDetailProvider(groupId));
    final myId = ref.watch(authSessionProvider).userId;
    final prepared = composer.prepared;

    final detail = detailAsync.valueOrNull;
    final recipients = [
      for (final m in detail?.members ?? const <GroupMember>[])
        if (m.userId != myId) m,
    ];
    final canSend = detail != null && recipients.isNotEmpty && prepared != null;

    return ColoredBox(
      color: AppColors.parchment,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 8.h, 20.w, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: composer.isSending ? null : onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.inkText,
                  ),
                  Text(
                    'Send snap',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkText,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
                children: [
                  if (prepared != null)
                    _Summary(
                      imagePath: prepared.path,
                      seconds: composer.viewSeconds,
                      caption: composer.caption.trim(),
                      sizeText: _size(prepared.compressedBytes),
                    ).slideIn(RevealDirection.bottom, distance: 12),
                  SizedBox(height: 18.h),
                  Row(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        size: 18.sp,
                        color: AppColors.emeraldInk,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          detail == null
                              ? 'Sending to the group'
                              : 'Sending to ${detail.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.worshipAccentBg,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${recipients.length}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.worshipAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13.sp,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 5.w),
                      Expanded(
                        child: Text(
                          'Everyone in the group receives this snap.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  if (detailAsync.isLoading && detail == null)
                    ShimmerBox(
                      width: double.infinity,
                      height: 150.h,
                      borderRadius: 22.r,
                    )
                  else if (detail == null)
                    SheetNotice(
                      message:
                          detailAsync.error?.toString() ??
                          'Couldn’t load the group members.',
                    )
                  else if (recipients.isEmpty)
                    _NoOne()
                  else
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(22.r),
                        border: Border.all(color: AppColors.borderWarm),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < recipients.length; i++) ...[
                            _Recipient(member: recipients[i]),
                            if (i != recipients.length - 1)
                              Divider(
                                height: 1,
                                indent: 66.w,
                                color: AppColors.borderWarm,
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 14.h),
              child: Column(
                children: [
                  SheetNotice(message: composer.errorMessage),
                  SheetButton(
                    label: recipients.length > 1
                        ? 'Send to ${recipients.length} members'
                        : 'Send snap',
                    icon: Icons.send_rounded,
                    loading: composer.isSending,
                    onPressed: canSend
                        ? () => onSend([for (final m in recipients) m.userId])
                        : null,
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

class _Summary extends StatelessWidget {
  final String imagePath;
  final int seconds;
  final String caption;
  final String sizeText;

  const _Summary({
    required this.imagePath,
    required this.seconds,
    required this.caption,
    required this.sizeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Image.file(
              File(imagePath),
              width: 84.w,
              height: 84.w,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 84.w,
                height: 84.w,
                color: AppColors.worshipAccentBg,
                child: Icon(
                  Icons.image_rounded,
                  color: AppColors.worshipAccent,
                ),
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.w,
                  runSpacing: 6.h,
                  children: [
                    _Chip(Icons.hourglass_bottom_rounded, '${seconds}s view'),
                    _Chip(Icons.compress_rounded, sizeText),
                  ],
                ),
                if (caption.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.emeraldInk.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: AppColors.amberDeep),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.amberDeep,
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only row: always "selected", with a lock so it's clear it can't be
/// changed.
class _Recipient extends StatelessWidget {
  final GroupMember member;
  const _Recipient({required this.member});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${member.displayName}, included',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        child: Row(
          children: [
            MemberAvatar(member: member, size: 42.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  RoleBadge(role: member.role),
                ],
              ),
            ),
            Icon(
              Icons.check_circle_rounded,
              size: 22.sp,
              color: AppColors.emeraldInk.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoOne extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_alt_1_rounded,
            size: 34.sp,
            color: AppColors.emeraldInk,
          ),
          SizedBox(height: 8.h),
          Text(
            'No one else is in this group yet',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Share the invite link first, then send your snap.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../groups/domain/entities/group.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../groups/presentation/widgets/group_image.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../providers/snap_providers.dart';

/// Last step: which groups get the snap. Each of the user's groups has a
/// checkbox; the group the flow was opened from is already ticked. Everyone in
/// a ticked group receives the snap, and individual members are deliberately
/// not shown or chosen.
class GroupPickerView extends ConsumerWidget {
  /// The group the flow was opened from, or null when it was opened from the
  /// groups list. Selects the composer's state.
  final String? initialGroupId;
  final VoidCallback onBack;

  /// Called with the ticked groups when the user taps Send.
  final void Function(List<String> groupIds) onSend;

  const GroupPickerView({
    super.key,
    required this.initialGroupId,
    required this.onBack,
    required this.onSend,
  });

  static String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composer = ref.watch(snapComposerProvider(initialGroupId));
    final controller = ref.read(snapComposerProvider(initialGroupId).notifier);
    final groupsAsync = ref.watch(myGroupsProvider);
    final prepared = composer.prepared;

    final groups = groupsAsync.valueOrNull ?? const <Group>[];
    // Only groups that still exist count: the user may have left one while
    // taking the photo.
    final chosen = [
      for (final g in groups)
        if (composer.selectedGroupIds.contains(g.id)) g.id,
    ];
    final canSend = prepared != null && chosen.isNotEmpty;
    final allChosen = groups.isNotEmpty && chosen.length == groups.length;

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
                          'Choose groups',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                      ),
                      if (chosen.isNotEmpty)
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
                            '${chosen.length} selected',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.worshipAccent,
                            ),
                          ),
                        ),
                      if (groups.length > 1) ...[
                        SizedBox(width: 6.w),
                        TextButton(
                          onPressed: composer.isSending
                              ? null
                              : () => controller.setGroups(
                                  allChosen
                                      ? const []
                                      : groups.map((g) => g.id),
                                ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.emeraldInk,
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                          ),
                          child: Text(allChosen ? 'Clear' : 'Select all'),
                        ),
                      ],
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
                          'Everyone in the groups you choose receives this snap. You can add more groups until this prayer’s time ends.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  if (groupsAsync.isLoading && !groupsAsync.hasValue)
                    ShimmerBox(
                      width: double.infinity,
                      height: 150.h,
                      borderRadius: 22.r,
                    )
                  else if (!groupsAsync.hasValue)
                    _LoadError(
                      message:
                          groupsAsync.error?.toString() ??
                          'Couldn’t load your groups.',
                      onRetry: () => ref.invalidate(myGroupsProvider),
                    )
                  else if (groups.isEmpty)
                    const _NoGroups()
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
                          for (var i = 0; i < groups.length; i++) ...[
                            GroupPickRow(
                              group: groups[i],
                              selected: composer.selectedGroupIds.contains(
                                groups[i].id,
                              ),
                              enabled: !composer.isSending,
                              onChanged: () =>
                                  controller.toggleGroup(groups[i].id),
                            ),
                            if (i != groups.length - 1)
                              Divider(
                                height: 1,
                                indent: 74.w,
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
                    label: chosen.isEmpty
                        ? 'Choose a group'
                        : chosen.length == 1
                        ? 'Send to 1 group'
                        : 'Send to ${chosen.length} groups',
                    icon: Icons.send_rounded,
                    loading: composer.isSending,
                    onPressed: canSend ? () => onSend(chosen) : null,
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

/// One group with its checkbox. The whole row is the tap target.
class GroupPickRow extends StatelessWidget {
  final Group group;
  final bool selected;
  final bool enabled;
  final VoidCallback onChanged;

  const GroupPickRow({
    super.key,
    required this.group,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final members = group.memberCount;
    return Semantics(
      container: true,
      checked: selected,
      inMutuallyExclusiveGroup: false,
      label: '${group.name}, $members ${members == 1 ? 'member' : 'members'}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? onChanged : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Row(
              children: [
                GroupImage(path: group.imagePath, size: 46.w, radius: 14.r),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
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
                        '$members ${members == 1 ? 'member' : 'members'}',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Checkbox(
                  value: selected,
                  onChanged: enabled ? (_) => onChanged() : null,
                  activeColor: AppColors.emeraldInk,
                  checkColor: AppColors.onEmeraldInk,
                  side: BorderSide(color: AppColors.textMuted, width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.r),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetNotice(message: message),
        SizedBox(height: 8.h),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _NoGroups extends StatelessWidget {
  const _NoGroups();

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
          Icon(Icons.groups_rounded, size: 34.sp, color: AppColors.emeraldInk),
          SizedBox(height: 8.h),
          Text(
            'You’re not in any group yet',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Create or join a group first, then send your snap.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

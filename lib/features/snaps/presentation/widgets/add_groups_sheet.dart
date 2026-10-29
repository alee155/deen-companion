import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../groups/domain/entities/group.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../../../prayer_logs/domain/prayer_log.dart';
import '../../../prayer_logs/domain/prayer_log_failure.dart';
import '../../../prayer_logs/presentation/prayer_labels.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'group_picker_view.dart';

/// What the sheet resolved with.
sealed class AddGroupsResult {
  const AddGroupsResult();
}

/// The snap was added to [count] more groups.
class AddedToGroups extends AddGroupsResult {
  final int count;
  const AddedToGroups(this.count);
}

/// The window closed while the sheet was open.
class SnapExpiredResult extends AddGroupsResult {
  const SnapExpiredResult();
}

/// "Send to more groups": the user's groups that do not have [log] yet, each
/// with a checkbox. The call is safe to repeat, so a double tap is harmless.
Future<AddGroupsResult?> showAddGroupsSheet(
  BuildContext context, {
  required PrayerLog log,
}) => showGroupSheet<AddGroupsResult>(context, (_) => AddGroupsSheet(log: log));

class AddGroupsSheet extends ConsumerStatefulWidget {
  final PrayerLog log;
  const AddGroupsSheet({super.key, required this.log});

  @override
  ConsumerState<AddGroupsSheet> createState() => _AddGroupsSheetState();
}

class _AddGroupsSheetState extends ConsumerState<AddGroupsSheet> {
  final Set<String> _selected = {};
  bool _sending = false;
  String? _error;

  Future<void> _add(List<String> ids) async {
    if (_sending || ids.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref
        .read(prayerLogActionsProvider)
        .addGroups(widget.log.id, ids);
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.of(context).pop(AddedToGroups(ids.length)),
      failure: (f) {
        if (f is PrayerLogFailure && f.code == PrayerLogErrorCode.snapExpired) {
          Navigator.of(context).pop(const SnapExpiredResult());
          return;
        }
        setState(() {
          _sending = false;
          _error = f is PrayerLogFailure ? prayerLogErrorMessage(f) : f.message;
        });
        // The user may have left a group: read the list again.
        if (f is PrayerLogFailure &&
            f.code == PrayerLogErrorCode.notGroupMember) {
          ref.invalidate(myGroupsProvider);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(myGroupsProvider);
    final all = groupsAsync.valueOrNull ?? const <Group>[];
    final groups = [
      for (final g in all)
        if (!widget.log.groupIds.contains(g.id)) g,
    ];
    // Only groups still on the list count: the user may have left one.
    final chosen = [
      for (final g in groups)
        if (_selected.contains(g.id)) g.id,
    ];
    final allChosen = groups.isNotEmpty && chosen.length == groups.length;

    return GroupSheetFrame(
      icon: Icons.group_add_rounded,
      title: 'Send to more groups',
      subtitle:
          'Choose where to send your snap. You can add more groups until this '
          'prayer’s time ends.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (groupsAsync.isLoading && !groupsAsync.hasValue)
            ShimmerBox(
              width: double.infinity,
              height: 120.h,
              borderRadius: 22.r,
            )
          else if (!groupsAsync.hasValue)
            SheetNotice(
              message:
                  groupsAsync.error?.toString() ?? 'Couldn’t load your groups.',
            )
          else if (groups.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(
                'Your snap is already in all of your groups.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else ...[
            if (groups.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _sending
                      ? null
                      : () => setState(() {
                          _selected
                            ..clear()
                            ..addAll(
                              allChosen ? const [] : groups.map((g) => g.id),
                            );
                        }),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.emeraldInk,
                  ),
                  child: Text(allChosen ? 'Clear' : 'Select all'),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 320.h),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(color: AppColors.borderWarm),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 74.w,
                    color: AppColors.borderWarm,
                  ),
                  itemBuilder: (_, i) => GroupPickRow(
                    key: ValueKey(groups[i].id),
                    group: groups[i],
                    selected: _selected.contains(groups[i].id),
                    enabled: !_sending,
                    onChanged: () => setState(() {
                      final id = groups[i].id;
                      if (!_selected.add(id)) _selected.remove(id);
                    }),
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: 14.h),
          SheetNotice(message: _error),
          SheetButton(
            label: chosen.isEmpty
                ? 'Choose a group'
                : chosen.length == 1
                ? 'Add to 1 group'
                : 'Add to ${chosen.length} groups',
            icon: Icons.send_rounded,
            loading: _sending,
            onPressed: chosen.isEmpty ? null : () => _add(chosen),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_detail.dart';
import '../providers/groups_providers.dart';
import 'group_form_widgets.dart';
import 'group_sheet_widgets.dart';

/// Admin-only: edit a group's name and description. Resolves true if saved.
Future<bool?> showEditGroupSheet(BuildContext context, GroupDetail group) {
  return showGroupSheet<bool>(context, (_) => EditGroupSheet(group: group));
}

class EditGroupSheet extends ConsumerStatefulWidget {
  final GroupDetail group;
  const EditGroupSheet({super.key, required this.group});

  @override
  ConsumerState<EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<EditGroupSheet> {
  static const _maxName = 255;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.group.name);
  late final _description = TextEditingController(
    text: widget.group.description,
  );

  bool get _dirty =>
      _name.text.trim() != widget.group.name ||
      _description.text.trim() != widget.group.description;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onChanged);
    _description.addListener(_onChanged);
  }

  void _onChanged() {
    // Typing again clears a stale server error.
    ref.read(groupManageControllerProvider.notifier).clearError();
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(groupManageControllerProvider.notifier)
        .update(
          widget.group.id,
          name: _name.text.trim(),
          description: _description.text.trim(),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupManageControllerProvider);
    final canSave = _dirty && !state.isSaving;

    return GroupSheetFrame(
      icon: Icons.edit_rounded,
      title: 'Edit group',
      subtitle: 'Update how your group appears to its members.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              enabled: !state.isSaving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: _maxName,
              decoration: groupInputDecoration(
                accent: AppColors.emeraldInk,
                label: 'Group name',
                hint: 'e.g. Family Quran Circle',
                icon: Icons.groups_rounded,
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Enter a group name';
                if (t.length < 3) return 'Use at least 3 characters';
                return null;
              },
            ).slideIn(RevealDirection.bottom, distance: 12),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _description,
              enabled: !state.isSaving,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: groupInputDecoration(
                accent: AppColors.emeraldInk,
                label: 'Description',
                hint: 'What is this group about?',
                icon: Icons.notes_rounded,
                alignLabelWithHint: true,
              ),
            ).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 50),
              distance: 12,
            ),
            SizedBox(height: 14.h),
            SheetNotice(message: state.errorMessage),
            Row(
              children: [
                Expanded(
                  child: SheetSecondaryButton(
                    label: 'Cancel',
                    onPressed: state.isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: SheetButton(
                    label: _dirty ? 'Save changes' : 'No changes yet',
                    icon: _dirty ? Icons.check_rounded : null,
                    loading: state.isSaving,
                    onPressed: canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_detail.dart';
import '../providers/groups_providers.dart';
import 'group_form_widgets.dart';
import 'group_image.dart';
import 'group_sheet_widgets.dart';

/// Admin-only: edit a group's name, description and picture. Resolves true if
/// saved.
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

  final _picker = ImagePicker();

  /// A newly picked local file, not yet uploaded.
  String? _imagePath;

  bool get _dirty =>
      _imagePath != null ||
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

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context);
    if (source == null) return;
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null || !mounted) return;
    ref.read(groupManageControllerProvider.notifier).clearError();
    setState(() => _imagePath = image.path);
  }

  Future<void> _removeImage() async {
    final ok = await ref
        .read(groupManageControllerProvider.notifier)
        .removeImage(widget.group.id);
    if (ok && mounted) Navigator.of(context).pop(true);
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
          imagePath: _imagePath,
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
            Row(
              children: [
                Pressable(
                  onTap: state.isSaving ? null : _pickImage,
                  haptic: true,
                  child: GroupImage(
                    path: _imagePath ?? widget.group.avatarUrl,
                    size: 72.w,
                    radius: 20.r,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Wrap(
                    spacing: 8.w,
                    children: [
                      TextButton.icon(
                        onPressed: state.isSaving ? null : _pickImage,
                        icon: Icon(Icons.add_a_photo_rounded, size: 16.sp),
                        label: Text(
                          _imagePath != null || widget.group.avatarUrl != null
                              ? 'Change photo'
                              : 'Add photo',
                        ),
                      ),
                      if (_imagePath != null)
                        TextButton(
                          onPressed: state.isSaving
                              ? null
                              : () => setState(() => _imagePath = null),
                          child: const Text('Discard'),
                        )
                      else if (widget.group.avatarUrl != null)
                        TextButton(
                          onPressed: state.isSaving ? null : _removeImage,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          child: const Text('Remove photo'),
                        ),
                    ],
                  ),
                ),
              ],
            ).slideIn(RevealDirection.bottom, distance: 12),
            SizedBox(height: 14.h),
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

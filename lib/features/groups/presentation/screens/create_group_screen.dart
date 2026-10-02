import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../domain/entities/group.dart';
import '../providers/groups_providers.dart';
import '../widgets/group_form_widgets.dart';
import '../widgets/group_image.dart';
import '../widgets/privacy_option_card.dart';

/// Pushed as a top-level route, so the bottom navigation bar is not shown.
/// Pops with the created [Group] so the caller can confirm it.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  String? _imagePath;
  GroupPrivacy _privacy = GroupPrivacy.public;
  bool _adminApproval = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 120 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _bar.value) _bar.value = t;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _scroll.dispose();
    _bar.dispose();
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
    setState(() => _imagePath = image.path);
  }

  void _setPrivacy(GroupPrivacy p) {
    HapticFeedback.selectionClick();
    setState(() {
      _privacy = p;
      _adminApproval = p == GroupPrivacy.private;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.heroSurface,
          content: Text(
            message,
            style: TextStyle(color: AppColors.onHeroSurface),
          ),
        ),
      );
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_imagePath == null) {
      _toast('Please add a group photo.');
      return;
    }
    setState(() => _isCreating = true);
    final result = await ref
        .read(myGroupsProvider.notifier)
        .create(
          NewGroup(
            name: _name.text.trim(),
            description: _description.text.trim(),
            privacy: _privacy,
            adminApproval: _adminApproval,
            imagePath: _imagePath,
          ),
        );
    if (!mounted) return;
    setState(() => _isCreating = false);
    result.when(
      success: (group) {
        HapticFeedback.mediumImpact();
        context.pop(group);
      },
      failure: (f) => _toast(f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        children: [
                          _hero(),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              20.w,
                              24.h,
                              20.w,
                              28.h,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const FormSectionTitle(
                                  title: 'Group details',
                                  subtitle:
                                      'Give your group a name and tell members what it is about.',
                                ).slideIn(
                                  RevealDirection.bottomStart,
                                  delay: const Duration(milliseconds: 200),
                                ),
                                SizedBox(height: 14.h),
                                TextFormField(
                                  controller: _name,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  style: TextStyle(
                                    color: AppColors.inkText,
                                    fontSize: 14.sp,
                                  ),
                                  validator: (v) {
                                    final t = v?.trim() ?? '';
                                    if (t.isEmpty)
                                      return 'Please enter a group name.';
                                    if (t.length < 3)
                                      return 'Group name must be at least 3 characters.';
                                    return null;
                                  },
                                  decoration: groupInputDecoration(
                                    label: 'Group name',
                                    hint: 'e.g. Family Quran Circle',
                                    icon: Icons.groups_rounded,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                TextFormField(
                                  controller: _description,
                                  maxLines: 4,
                                  maxLength: 250,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: TextStyle(
                                    color: AppColors.inkText,
                                    fontSize: 14.sp,
                                    height: 1.45,
                                  ),
                                  validator: (v) => (v?.trim().isEmpty ?? true)
                                      ? 'Please add a short description.'
                                      : null,
                                  decoration: groupInputDecoration(
                                    label: 'Description',
                                    hint: 'What is this group about?',
                                    icon: Icons.notes_rounded,
                                    alignLabelWithHint: true,
                                  ),
                                ),
                                SizedBox(height: 14.h),
                                const FormSectionTitle(
                                  title: 'Privacy',
                                  subtitle: 'Choose who can join your group.',
                                ).slideIn(
                                  RevealDirection.topStart,
                                  onVisible: true,
                                ),
                                SizedBox(height: 14.h),
                                PrivacyOptionCard(
                                  selected: _privacy == GroupPrivacy.public,
                                  icon: Icons.public_rounded,
                                  title: 'Public group',
                                  description:
                                      'Anyone can discover and join this group.',
                                  onTap: () => _setPrivacy(GroupPrivacy.public),
                                ).slideIn(
                                  RevealDirection.start,
                                  onVisible: true,
                                ),
                                SizedBox(height: 10.h),
                                PrivacyOptionCard(
                                  selected: _privacy == GroupPrivacy.private,
                                  icon: Icons.lock_rounded,
                                  title: 'Private group',
                                  description:
                                      'Only approved members can join this group.',
                                  onTap: () =>
                                      _setPrivacy(GroupPrivacy.private),
                                ).slideIn(
                                  RevealDirection.end,
                                  onVisible: true,
                                  delay: const Duration(milliseconds: 60),
                                ),
                                SizedBox(height: 14.h),
                                ApprovalToggleCard(
                                  value: _adminApproval,
                                  onChanged: (v) => setState(() {
                                    _adminApproval = v;
                                    if (v) _privacy = GroupPrivacy.private;
                                  }),
                                ).slideIn(
                                  RevealDirection.bottomStart,
                                  onVisible: true,
                                ),
                                SizedBox(height: 14.h),
                                Container(
                                  padding: EdgeInsets.all(14.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(18.r),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 19.sp,
                                        color: AppColors.gold,
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Text(
                                          'You can change these settings later from the group management screen.',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            height: 1.45,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).slideIn(
                                  RevealDirection.bottomEnd,
                                  onVisible: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _bottomBar().slideIn(
                    RevealDirection.bottom,
                    delay: const Duration(milliseconds: 300),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(opacity: _bar, title: 'Create group'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 52,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + 64.h,
              24.w,
              26.h,
            ),
            child: Column(
              children: [
                Pressable(
                  onTap: _pickImage,
                  haptic: true,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 124.w,
                        height: 124.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34.r),
                          border: Border.all(color: AppColors.gold, width: 1.6),
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        child: _imagePath != null
                            ? GroupImage(
                                path: _imagePath,
                                size: 124.w,
                                radius: 32.r,
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 32.sp,
                                    color: AppColors.goldLight,
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Add photo',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.goldLight,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      Positioned(
                        right: -6.w,
                        bottom: -6.w,
                        child: Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold,
                            border: Border.all(
                              color: AppColors.heroSurface,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            _imagePath == null
                                ? Icons.add_rounded
                                : Icons.edit_rounded,
                            size: 18.sp,
                            color: AppColors.heroSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Start a new group',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ).slideIn(RevealDirection.bottom),
                SizedBox(height: 4.h),
                Text(
                  'Read together and keep each other consistent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                  ),
                ).slideIn(
                  RevealDirection.top,
                  delay: const Duration(milliseconds: 70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.borderWarm)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52.h,
          child: FilledButton(
            onPressed: _isCreating ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.heroSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: _isCreating
                ? SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.heroSurface,
                    ),
                  )
                : Text(
                    'Create group',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../groups/presentation/widgets/group_form_widgets.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../providers/profile_providers.dart';

/// Change the name and picture. Pushed as a top-level route.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _name;
  late final String _originalName;

  /// A newly picked local file, not yet uploaded.
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _originalName = ref.read(authSessionProvider).name?.trim() ?? '';
    _name = TextEditingController(text: _originalName)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _dirty => _imagePath != null || _name.text.trim() != _originalName;

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context, title: 'Profile photo');
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

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || !_dirty) return;
    final name = _name.text.trim();
    final ok = await ref
        .read(profileEditControllerProvider.notifier)
        .save(name: name == _originalName ? null : name, imagePath: _imagePath);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      context.pop(true);
    } else {
      _toast(
        ref.read(profileEditControllerProvider).errorMessage ??
            'Couldn’t save your profile. Try again.',
      );
    }
  }

  Future<void> _removePhoto() async {
    final ok = await ref
        .read(profileEditControllerProvider.notifier)
        .removePhoto();
    if (!mounted) return;
    if (ok) {
      setState(() => _imagePath = null);
      _toast('Photo removed.');
    } else {
      _toast(
        ref.read(profileEditControllerProvider).errorMessage ??
            'Couldn’t remove your photo. Try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final saving = ref.watch(profileEditControllerProvider).isSaving;
    final remote = session.photoUrl;
    final hasPhoto = _imagePath != null || remote != null;

    final ImageProvider? image = _imagePath != null
        ? FileImage(File(_imagePath!))
        : remote != null
        ? CachedNetworkImageProvider(remote)
        : null;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.inkText,
        title: Text(
          'Edit profile',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Center(
              child: GestureDetector(
                onTap: saving ? null : _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52.w,
                      backgroundColor: AppColors.heroSurface,
                      backgroundImage: image,
                      onBackgroundImageError: image == null ? null : (_, _) {},
                      child: image == null
                          ? Text(
                              session.initials,
                              style: TextStyle(
                                fontSize: 30.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.goldLight,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.parchment,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 16.sp,
                          color: AppColors.heroSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasPhoto)
              Center(
                child: TextButton(
                  onPressed: saving
                      ? null
                      : _imagePath != null
                      ? () => setState(() => _imagePath = null)
                      : _removePhoto,
                  child: Text(
                    _imagePath != null ? 'Discard new photo' : 'Remove photo',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            SizedBox(height: 16.h),
            Text(
              'Name',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _name,
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: maxProfileNameLength,
              onFieldSubmitted: (_) => _save(),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter your name' : null,
              decoration: _decoration('Your name'),
            ),
            SizedBox(height: 12.h),
            Text(
              'Email',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              initialValue: session.email ?? '',
              enabled: false,
              decoration: _decoration(null),
            ),
            SizedBox(height: 28.h),
            FilledButton(
              onPressed: saving || !_dirty ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.heroSurface,
                minimumSize: Size.fromHeight(52.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: saving
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save changes',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String? hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surfaceLight,
    counterText: '',
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: BorderSide(color: AppColors.borderWarm),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: BorderSide(color: AppColors.borderWarm),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: BorderSide(color: AppColors.borderWarm),
    ),
  );
}

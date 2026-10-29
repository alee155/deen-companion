import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/gender.dart';
import '../../../auth/presentation/widgets/gender_selector.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../providers/gender_prompt_providers.dart';

/// The one-time question for accounts that were created before gender was
/// collected. Resolves true once it is saved.
Future<bool?> showGenderPrompt(BuildContext context) =>
    showGroupSheet<bool>(context, (_) => const GenderPromptSheet());

class GenderPromptSheet extends ConsumerStatefulWidget {
  const GenderPromptSheet({super.key});

  @override
  ConsumerState<GenderPromptSheet> createState() => _GenderPromptSheetState();
}

class _GenderPromptSheetState extends ConsumerState<GenderPromptSheet> {
  Gender? _gender;

  Future<void> _save() async {
    final gender = _gender;
    if (gender == null) return;
    final ok = await ref
        .read(genderPromptControllerProvider.notifier)
        .save(gender);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(genderPromptControllerProvider);
    return GroupSheetFrame(
      icon: Icons.person_outline_rounded,
      title: 'One quick question',
      subtitle: 'Tell us your gender to finish setting up your account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GenderSelector(
            value: _gender,
            enabled: !state.isSaving,
            onChanged: (g) => setState(() => _gender = g),
          ),
          SizedBox(height: 10.h),
          Text(
            'You can only set this once. It can’t be changed afterwards.',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
          ),
          SizedBox(height: 14.h),
          SheetNotice(message: state.errorMessage),
          SheetButton(
            label: 'Save',
            loading: state.isSaving,
            onPressed: _gender == null ? null : _save,
          ),
          SizedBox(height: 6.h),
          Center(
            child: TextButton(
              onPressed: state.isSaving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Watches whether the gender is still missing and asks once per app run. Put
/// it around the signed-in part of the app.
class GenderPromptHost extends ConsumerStatefulWidget {
  final Widget child;
  const GenderPromptHost({super.key, required this.child});

  @override
  ConsumerState<GenderPromptHost> createState() => _GenderPromptHostState();
}

class _GenderPromptHostState extends ConsumerState<GenderPromptHost> {
  bool _showing = false;

  Future<void> _ask() async {
    if (_showing) return;
    _showing = true;
    final saved = await showGenderPrompt(context);
    _showing = false;
    // Closed without answering: leave it until the next launch.
    if (saved != true && mounted) {
      ref.read(genderPromptDismissedProvider.notifier).state = true;
    }
  }

  void _askSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(genderPromptNeededProvider)) _ask();
    });
  }

  @override
  void initState() {
    super.initState();
    // The profile may already be loaded when this appears.
    _askSoon();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(genderPromptNeededProvider, (_, needed) {
      if (needed) _askSoon();
    });
    return widget.child;
  }
}

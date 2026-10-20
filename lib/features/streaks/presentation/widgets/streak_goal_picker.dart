import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../../domain/entities/streak_rule.dart';
import '../providers/streaks_providers.dart';

/// Admin only: how many prayers a day keeps the streak alive. Five choices
/// (1 to 5) and a save button that only lights up once the value changes.
class StreakGoalPicker extends ConsumerStatefulWidget {
  final String groupId;
  final StreakRule current;
  const StreakGoalPicker({required this.groupId, required this.current});

  @override
  ConsumerState<StreakGoalPicker> createState() => _StreakGoalPickerState();
}

class _StreakGoalPickerState extends ConsumerState<StreakGoalPicker> {
  int? _picked;

  int get _value => _picked ?? widget.current.minPrayers;

  Future<void> _save() async {
    final ok = await ref
        .read(streakRuleControllerProvider.notifier)
        .save(widget.groupId, _value);
    if (ok && mounted) setState(() => _picked = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(streakRuleControllerProvider);
    final changed = _value != widget.current.minPrayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var n = StreakRule.minAllowed; n <= StreakRule.maxAllowed; n++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: n == StreakRule.maxAllowed ? 0 : 8.w,
                  ),
                  child: _Choice(
                    n: n,
                    selected: n == _value,
                    onTap: state.isSaving
                        ? null
                        : () => setState(() => _picked = n),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 14.h),
        SheetNotice(message: state.errorMessage),
        SheetButton(
          label: 'Save goal',
          icon: Icons.check_rounded,
          loading: state.isSaving,
          onPressed: changed ? _save : null,
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  final int n;
  final bool selected;
  final VoidCallback? onTap;
  const _Choice({required this.n, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$n ${n == 1 ? 'prayer' : 'prayers'} a day',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: !selected,
        scale: 0.95,
        child: AnimatedContainer(
          duration: context.motion.duration(AppMotion.fast),
          height: 46.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.emeraldInk : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected ? AppColors.emeraldInk : AppColors.borderWarm,
            ),
          ),
          child: Text(
            '$n',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.onEmeraldInk : AppColors.inkText,
            ),
          ),
        ),
      ),
    );
  }
}

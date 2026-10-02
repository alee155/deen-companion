import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/reliability_requirement.dart';
import '../providers/reliability_providers.dart';

/// Opens the setup checklist. Resolves when it is closed.
Future<void> showReliabilitySetupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: AppMotion.sheetStyle,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (_) => const _SetupSheet(),
  );
}

/// One checklist for everything reminders and notifications need, asked
/// upfront rather than at the moment an alert is due. "Allow all" walks the
/// missing items in order, one system prompt at a time; each row can also be
/// allowed on its own.
class _SetupSheet extends ConsumerStatefulWidget {
  const _SetupSheet();

  @override
  ConsumerState<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends ConsumerState<_SetupSheet> {
  ReliabilityRequirement? _current;
  bool _busy = false;

  Future<void> _allowAll() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    await ref
        .read(reliabilityServiceProvider)
        .setUpAll(
          onStep: (r) {
            if (mounted) setState(() => _current = r);
          },
        );
    if (!mounted) return;
    setState(() => _busy = false);
    final status = await ref.read(reliabilityStatusProvider.future);
    if (mounted && status.allGranted) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _allowOne(ReliabilityRequirement r) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _current = r;
    });
    await ref.read(reliabilityServiceProvider).request(r);
    await ref.read(reliabilityServiceProvider).rearm();
    if (mounted) {
      setState(() {
        _busy = false;
        _current = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(reliabilityStatusProvider).value;
    final missing = status?.missing ?? const <ReliabilityRequirement>[];
    final done = status != null && status.allGranted;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.borderWarm,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              done ? 'You’re all set' : 'Set up on-time reminders',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              done
                  ? 'Prayer alarms and your daily Ayat & Hadith will arrive '
                        'exactly on time.'
                  : 'Prayer alarms and daily notifications only work on time '
                        'if Android allows them. Doing it now means nothing '
                        'is missed later.',
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 14.h),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final r in ReliabilityRequirement.values)
                      if (status == null || status.containsKey(r))
                        _Row(
                          requirement: r,
                          granted: status?[r] ?? false,
                          active: _current == r,
                          enabled: !_busy,
                          onAllow: () => _allowOne(r),
                        ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            if (!done)
              SizedBox(
                height: 52.h,
                child: FilledButton(
                  onPressed: _busy || missing.isEmpty ? null : _allowAll,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emeraldInk,
                    foregroundColor: AppColors.onEmeraldInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                  child: Text(
                    _busy
                        ? 'Follow the prompts…'
                        : 'Allow all (${missing.length})',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(
                done ? 'Done' : 'Not now',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: done ? AppColors.emeraldInk : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final ReliabilityRequirement requirement;
  final bool granted;
  final bool active;
  final bool enabled;
  final VoidCallback onAllow;

  const _Row({
    required this.requirement,
    required this.granted,
    required this.active,
    required this.enabled,
    required this.onAllow,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.motion.duration(AppMotion.normal),
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: active
            ? AppColors.emeraldInk.withValues(alpha: 0.07)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: active
              ? AppColors.emeraldInk.withValues(alpha: 0.45)
              : AppColors.borderWarm,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.worshipAccentBg,
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Icon(
              requirement.icon,
              size: 20.sp,
              color: AppColors.worshipAccent,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  requirement.why,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ContentSwitcher(
            child: granted
                ? Icon(
                    Icons.check_circle_rounded,
                    key: const ValueKey('ok'),
                    size: 24.sp,
                    color: AppColors.success,
                  )
                : active
                ? SizedBox(
                    key: const ValueKey('busy'),
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.emeraldInk,
                    ),
                  )
                : TextButton(
                    key: const ValueKey('allow'),
                    onPressed: enabled ? onAllow : null,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.worshipAccentBg,
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      minimumSize: Size(0, 32.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Allow',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.worshipAccent,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/current_prayer.dart';
import '../../domain/prayer_log.dart';
import '../prayer_labels.dart';
import '../providers/prayer_logs_providers.dart';

/// Home: what prayer is open, with a countdown and the Log / Undo action,
/// plus today's five-prayer checklist. Hidden for guests.
class PrayerLogCard extends ConsumerStatefulWidget {
  const PrayerLogCard({super.key});

  @override
  ConsumerState<PrayerLogCard> createState() => _PrayerLogCardState();
}

class _PrayerLogCardState extends ConsumerState<PrayerLogCard>
    with WidgetsBindingObserver {
  Timer? _ticker;

  /// Server clock minus device clock, measured when the state arrived, so the
  /// countdown follows the server's windows even if the phone's clock is off.
  Duration _skew = Duration.zero;
  CurrentPrayerState? _seen;
  bool _refreshRequested = false;

  DateTime get _now => DateTime.now().add(_skew);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    _refreshRequested = true;
    ref.read(currentPrayerProvider.notifier).refresh();
    ref.invalidate(prayerLogsProvider);
  }

  void _tick() {
    if (!mounted) return;
    final s = ref.read(currentPrayerProvider).valueOrNull;
    if (s == null) return;
    // A window just opened or closed: ask the server what is open now, once.
    final boundary = s.current?.endsAt ?? s.next?.startsAt;
    if (boundary != null && !_now.isBefore(boundary) && !_refreshRequested) {
      _refresh();
    }
    setState(() {});
  }

  void _track(CurrentPrayerState s) {
    if (!identical(s, _seen)) {
      _seen = s;
      _skew = s.now.difference(DateTime.now());
      _refreshRequested = false;
    }
  }

  Future<void> _log() async {
    HapticFeedback.selectionClick();
    final logged = await context.push<bool>('/prayer-log/new');
    if (logged == true && mounted) _toast('Prayer logged');
  }

  Future<void> _undo(CurrentPrayer current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${current.prayer.label} log?'),
        content: const Text(
          'Your photo will be deleted. You can log again while this '
          'prayer’s time is still open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || current.logId == null || !mounted) return;
    final result = await ref
        .read(prayerLogActionsProvider)
        .undo(current.logId!);
    if (!mounted) return;
    result.when(
      success: (_) => _toast('Log removed'),
      failure: (f) => _toast(prayerLogErrorMessage(f)),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(authSessionProvider).isAuthenticated) {
      return const SizedBox.shrink();
    }
    final async = ref.watch(currentPrayerProvider);
    final today =
        ref.watch(prayerLogsProvider(null)).valueOrNull ?? const <PrayerLog>[];

    final Widget content = async.when(
      data: (s) {
        _track(s);
        return _loaded(s, today);
      },
      loading: () => async.hasValue
          ? _loaded(async.value!, today)
          : ShimmerBox(
              width: double.infinity,
              height: 176.h,
              borderRadius: 22.r,
            ),
      error: (e, _) => _problem(
        async.hasValue ? null : 'Couldn’t load your prayer log.',
        retry: _refresh,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: content,
    );
  }

  Widget _problem(String? message, {required VoidCallback retry}) {
    return _shell(
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: AppColors.textMuted),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              message ?? 'Couldn’t refresh.',
              style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
            ),
          ),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _loaded(CurrentPrayerState s, List<PrayerLog> today) {
    final now = _now;
    final current = s.current;

    if (s.isNotSynced) {
      return _problem('Setting up your prayer times…', retry: _refresh);
    }

    final String title;
    final String subtitle;
    final IconData icon;
    if (current != null) {
      title = current.logged
          ? '${current.prayer.label} logged'
          : '${current.prayer.label} is open';
      subtitle = 'Ends in ${countdown(current.endsAt.difference(now))}';
      icon = current.logged ? Icons.check_circle_rounded : Icons.mosque_rounded;
    } else {
      final next = s.next;
      title = 'No prayer open';
      subtitle = next == null
          ? 'Check back soon'
          : 'Next: ${next.prayer.label} at ${clockTime(next.startsAt)}';
      icon = Icons.schedule_rounded;
    }

    return _shell(
      onTap: () => context.push('/prayer-log'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.worshipAccentBg,
                ),
                child: Icon(icon, color: AppColors.emeraldInk, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
          SizedBox(height: 14.h),
          _action(current, now),
          SizedBox(height: 14.h),
          _Checklist(logs: today, open: current),
        ],
      ),
    );
  }

  Widget _action(CurrentPrayer? current, DateTime now) {
    if (current != null && current.logged) {
      final canUndo = now.isBefore(current.endsAt) && current.logId != null;
      return Row(
        children: [
          Icon(Icons.verified_rounded, color: AppColors.success, size: 18.sp),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              'Done — may Allah accept it',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (canUndo)
            TextButton(
              onPressed: () => _undo(current),
              child: const Text('Undo'),
            ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 46.h,
      child: FilledButton.icon(
        onPressed: current == null ? null : _log,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.emeraldInk,
          foregroundColor: AppColors.onEmeraldInk,
          disabledBackgroundColor: AppColors.borderWarm,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        icon: const Icon(Icons.camera_alt_rounded),
        label: Text(
          current == null ? 'Log prayer' : 'Log ${current.prayer.label}',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _shell({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(22.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(22.r),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Fajr … Isha, filled for what today's logs contain.
class _Checklist extends StatelessWidget {
  final List<PrayerLog> logs;
  final CurrentPrayer? open;
  const _Checklist({required this.logs, required this.open});

  @override
  Widget build(BuildContext context) {
    final done = {for (final l in logs) l.prayer};
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final p in PrayerName.values)
          _Chip(
            label: p.label,
            done: done.contains(p) || (open?.prayer == p && open!.logged),
            isOpen: open?.prayer == p,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool done;
  final bool isOpen;
  const _Chip({required this.label, required this.done, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label ${done ? 'logged' : 'not logged'}',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.emeraldInk : Colors.transparent,
              border: Border.all(
                color: done || isOpen
                    ? AppColors.emeraldInk
                    : AppColors.borderWarm,
                width: isOpen && !done ? 2 : 1.4,
              ),
            ),
            child: done
                ? Icon(
                    Icons.check_rounded,
                    size: 17.sp,
                    color: AppColors.onEmeraldInk,
                  )
                : null,
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: isOpen ? FontWeight.w800 : FontWeight.w600,
              color: isOpen ? AppColors.inkText : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

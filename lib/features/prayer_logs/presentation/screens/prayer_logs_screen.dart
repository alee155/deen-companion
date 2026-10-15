import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/prayer_log.dart';
import '../prayer_labels.dart';
import '../providers/prayer_logs_providers.dart';
import '../widgets/snap_photo_viewer.dart';

/// Your prayer log for one day: the five prayers, with points and photos.
/// Opened from the home card; step back and forward through past days.
class PrayerLogsScreen extends ConsumerStatefulWidget {
  const PrayerLogsScreen({super.key});

  @override
  ConsumerState<PrayerLogsScreen> createState() => _PrayerLogsScreenState();
}

class _PrayerLogsScreenState extends ConsumerState<PrayerLogsScreen> {
  static final _wire = DateFormat('yyyy-MM-dd');

  late DateTime _today = _dateOnly(DateTime.now());
  late DateTime _day = _today;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isToday => _day == _today;

  /// Today is requested without a date so the server applies the user's own
  /// timezone; other days are explicit.
  String? get _requestDate => _isToday ? null : _wire.format(_day);

  void _shift(int days) {
    setState(() {
      _today = _dateOnly(DateTime.now());
      final next = DateTime(_day.year, _day.month, _day.day + days);
      _day = next.isAfter(_today) ? _today : next;
    });
    FlowLog.log(
      'CHECKLIST',
      'USER MOVED TO ${_isToday ? 'TODAY' : _wire.format(_day)}',
    );
  }

  String get _title => _isToday
      ? 'Today'
      : _day == DateTime(_today.year, _today.month, _today.day - 1)
      ? 'Yesterday'
      : DateFormat('EEE, d MMM').format(_day);

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(prayerLogsProvider(_requestDate));

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.inkText,
        title: Text(
          'Prayer log',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(prayerLogsProvider(_requestDate));
          await ref.read(prayerLogsProvider(_requestDate).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 32.h),
          children: [
            _DayBar(
              title: _title,
              canGoForward: !_isToday,
              onBack: () => _shift(-1),
              onForward: () => _shift(1),
            ),
            SizedBox(height: 14.h),
            logs.when(
              data: (list) => _Day(
                logs: list,
                onUndo: (log) async {
                  final r = await ref
                      .read(prayerLogActionsProvider)
                      .undo(log.id);
                  if (!context.mounted) return;
                  r.when(
                    success: (_) => _toast(context, 'Log removed'),
                    failure: (f) => _toast(context, prayerLogErrorMessage(f)),
                  );
                },
              ),
              loading: () => Column(
                children: [
                  for (var i = 0; i < 5; i++) ...[
                    ShimmerBox(
                      width: double.infinity,
                      height: 64.h,
                      borderRadius: 18.r,
                    ),
                    SizedBox(height: 10.h),
                  ],
                ],
              ),
              error: (e, _) => Padding(
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: Column(
                  children: [
                    Text(
                      e.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 10.h),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(prayerLogsProvider(_requestDate)),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }
}

class _DayBar extends StatelessWidget {
  final String title;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  const _DayBar({
    required this.title,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous day',
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.inkText,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          onPressed: canGoForward ? onForward : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  final List<PrayerLog> logs;
  final ValueChanged<PrayerLog> onUndo;
  const _Day({required this.logs, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final byPrayer = {for (final l in logs) l.prayer: l};
    final points = logs.fold<int>(0, (sum, l) => sum + l.points);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
          child: Text(
            '${byPrayer.length} of 5 prayers · $points points',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        for (final prayer in PrayerName.values) ...[
          _Row(
            prayer: prayer,
            log: byPrayer[prayer],
            canUndo: byPrayer[prayer]?.canUndo(now) ?? false,
            onUndo: onUndo,
          ),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final PrayerName prayer;
  final PrayerLog? log;
  final bool canUndo;
  final ValueChanged<PrayerLog> onUndo;
  const _Row({
    required this.prayer,
    required this.log,
    required this.canUndo,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final l = log;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: [
          Icon(
            l == null
                ? Icons.radio_button_unchecked_rounded
                : Icons.check_circle_rounded,
            color: l == null ? AppColors.textMuted : AppColors.emeraldInk,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayer.label,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                Text(
                  l == null
                      ? 'Not logged'
                      : 'Logged at ${clockTime(l.loggedAt)}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (l != null) ...[
            Text(
              '+${l.points}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.worshipAccent,
              ),
            ),
            SizedBox(width: 10.w),
            if (l.snapUrl != null)
              GestureDetector(
                onTap: () => showSnapPhoto(
                  context,
                  url: l.snapUrl!,
                  title: prayer.label,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: SizedBox(
                    width: 44.w,
                    height: 44.w,
                    child: SnapPhoto(url: l.snapUrl!),
                  ),
                ),
              ),
            if (canUndo)
              TextButton(onPressed: () => onUndo(l), child: const Text('Undo')),
          ],
        ],
      ),
    );
  }
}

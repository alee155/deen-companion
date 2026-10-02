import 'dart:async';

import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/permissions/notification_permission_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/domain/explore_icon_assets.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../reliability_setup/domain/reliability_requirement.dart';
import '../../../reliability_setup/presentation/providers/reliability_providers.dart';
import '../../../reliability_setup/presentation/widgets/reliability_setup_sheet.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';
import '../../../prayer_times/presentation/widgets/prayer_hero.dart'
    show PrayerTimesOrdered, prayerLabels;
import '../../domain/prayer_reminder_prefs.dart';
import '../providers/reminders_provider.dart';
import '../widgets/prayer_reminder_card.dart';

/// Prayer reminders: master switch, then per-prayer alarm and snooze
/// settings. Everything here only *configures* — arming, ringing, snoozing
/// and cancelling stay in the native alarm pipeline, and the screen shows a
/// change as saved only once the native side has confirmed it.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);
  Timer? _clearTimer;
  bool _busy = false;
  bool _showInfo = false;
  PrayerName? _expanded;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 140 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _bar.value) _bar.value = t;
    });
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  void _setApply(ReminderApplyState state) =>
      ref.read(reminderApplyProvider.notifier).set(state);

  Future<void> _onToggle(bool enabled) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    _setApply(const ReminderApplying());

    final notifier = ref.read(remindersEnabledProvider.notifier);
    final service = ref.read(prayerReminderServiceProvider);

    try {
      if (!enabled) {
        await notifier.set(false);
        await service.cancelAll();
        _setApply(const ReminderApplied('Reminders off — no alarms armed.'));
        return;
      }

      final granted = await _ensurePermissions();
      if (!granted) {
        await notifier.set(false);
        _setApply(
          const ReminderApplyFailed(
            'Notification permission is needed before reminders can be '
            'switched on.',
          ),
        );
        return;
      }

      await notifier.set(true);
      final result = await service.sync();
      if (result is ReminderSyncFailed) {
        await notifier.set(false);
        _setApply(ReminderApplyFailed(result.message));
      } else {
        _setApply(ReminderApplied(describeSync(result)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reminders need the full upfront set (notifications, exact alarms,
  /// full-screen alerts, battery). Normally Home has already collected them;
  /// if anything is still missing the same checklist opens here. Only
  /// notifications are mandatory — the rest affect reliability, not whether
  /// reminders can be switched on.
  Future<bool> _ensurePermissions() async {
    final reliability = ref.read(reliabilityServiceProvider);
    final status = await reliability.check();
    if (!status.allGranted) {
      if (!mounted) return false;
      await showReliabilitySetupSheet(context);
    }
    return ref.read(notificationPermissionServiceProvider).isGranted();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(remindersEnabledProvider);
    final prefs = ref.watch(prayerReminderPrefsProvider);
    final times = ref.watch(prayerTimesNotifierProvider).value;

    // A "saved" confirmation fades back to idle on its own; failures stay
    // until the next change so they can't be missed.
    ref.listen(reminderApplyProvider, (_, next) {
      _clearTimer?.cancel();
      if (next is ReminderApplied) {
        _clearTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && ref.read(reminderApplyProvider) is ReminderApplied) {
            _setApply(const ReminderIdle());
          }
        });
      }
    });

    final activeCount = prefs.values.where((p) => p.enabled).length;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _hero(enabled, activeCount, times)),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                  sliver: SliverToBoxAdapter(child: _masterCard(enabled)),
                ),
                SliverToBoxAdapter(
                  child: _sectionHeader(enabled, prefs, activeCount),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  sliver: SliverList.separated(
                    itemCount: PrayerName.values.length,
                    separatorBuilder: (_, _) => SizedBox(height: 10.h),
                    itemBuilder: (context, i) {
                      final prayer = PrayerName.values[i];
                      final time = times?.ordered
                          .firstWhere((e) => e.key == prayer)
                          .value;
                      return AnimatedOpacity(
                        duration: context.motion.duration(AppMotion.normal),
                        opacity: enabled ? 1 : 0.5,
                        child: IgnorePointer(
                          ignoring: !enabled,
                          child: PrayerReminderCard(
                            prayer: prayer,
                            time: time,
                            prefs: prefs[prayer]!,
                            expanded: _expanded == prayer,
                            onToggleExpanded: () => setState(
                              () => _expanded = _expanded == prayer
                                  ? null
                                  : prayer,
                            ),
                            onChanged: (next) {
                              // Switching a prayer off collapses its card.
                              if (!next.enabled && _expanded == prayer) {
                                setState(() => _expanded = null);
                              }
                              ref
                                  .read(prayerReminderPrefsProvider.notifier)
                                  .update(prayer, next);
                            },
                          ),
                        ),
                      ).slideInAt(i, distance: 18);
                    },
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                  sliver: SliverToBoxAdapter(child: _infoCard()),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
                  sliver: const SliverToBoxAdapter(
                    child: BannerAdWidget(
                      margin: EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 32.h,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(opacity: _bar, title: 'Prayer Reminders'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(bool enabled, int activeCount, PrayerTimes? times) {
    String? next;
    if (times != null) {
      final n = times.nextPrayer(DateTime.now());
      next = '${prayerLabels[n.key]} ${DateFormat('h:mm a').format(n.value)}';
    }
    return FeatureHero(
      title: 'Prayer Reminders',
      subtitle: 'Real alarms that ring even when the app is closed.',
      ghostIcon: Icons.alarm_rounded,
      chips: [
        FeatureHeroChip(
          Icons.alarm_on_rounded,
          enabled ? '$activeCount of 5 active' : 'Reminders off',
        ),
        if (next != null)
          FeatureHeroChip(Icons.schedule_rounded, 'Next: $next'),
      ],
    );
  }

  Widget _masterCard(bool enabled) {
    final apply = ref.watch(reminderApplyProvider);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: enabled
              ? AppColors.emeraldInk.withValues(alpha: 0.4)
              : AppColors.borderWarm,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                padding: EdgeInsets.all(11.w),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.borderWarm, width: 1.2.w),
                ),
                child: Image.asset(
                  exploreIconAssets['reminders']!,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prayer reminders',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    AnimatedText(
                      enabled
                          ? 'On — alarms are armed'
                          : 'Off — turn on to choose prayers',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enabled,
                activeThumbColor: AppColors.emeraldInk,
                onChanged: _busy ? null : _onToggle,
              ),
            ],
          ),
          ContentSwitcher(child: _status(apply)),
        ],
      ),
    );
  }

  /// Reflects the real outcome of the last native apply: progress, the
  /// confirmed result, or the failure — nothing in between.
  Widget _status(ReminderApplyState apply) {
    switch (apply) {
      case ReminderIdle():
        return const SizedBox(key: ValueKey('idle'), width: double.infinity);
      case ReminderApplying():
        return Padding(
          key: const ValueKey('applying'),
          padding: EdgeInsets.only(top: 12.h),
          child: Row(
            children: [
              SizedBox(
                width: 14.w,
                height: 14.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.emeraldInk,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'Applying to your alarms…',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      case ReminderApplied(:final message):
        return _StatusLine(
          key: ValueKey('ok-$message'),
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          background: AppColors.quranAccentBg,
          message: message,
        );
      case ReminderApplyFailed(:final message):
        return _StatusLine(
          key: ValueKey('err-$message'),
          icon: Icons.error_rounded,
          color: AppColors.error,
          background: AppColors.hadithAccentBg,
          message: message,
        );
    }
  }

  Widget _sectionHeader(bool enabled, PrayerPrefsMap prefs, int activeCount) {
    final allOn = activeCount == PrayerName.values.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 12.h),
      child: Row(
        children: [
          Text(
            'Your prayers',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.worshipAccentBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              '$activeCount/5',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.worshipAccent,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(prayerReminderPrefsProvider.notifier)
                        .setAllEnabled(!allOn);
                  }
                : null,
            child: Text(
              allOn ? 'Turn all off' : 'Turn all on',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w800,
                color: enabled ? AppColors.worshipAccent : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22.r),
            onTap: () => setState(() => _showInfo = !_showInfo),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 19.sp,
                    color: AppColors.worshipAccent,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'How reminders work',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showInfo ? 0.5 : 0,
                    duration: context.motion.duration(AppMotion.normal),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ExpandSection(
            expanded: _showInfo,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
              child: Column(
                children: const [
                  _InfoLine(
                    Icons.schedule_rounded,
                    'Follows the calculation method and Asr school you set in '
                    'Settings, for your current location.',
                  ),
                  _InfoLine(
                    Icons.offline_bolt_rounded,
                    'A week of alarms is armed ahead of time, so they keep '
                    'ringing offline, with the app closed, and after a restart.',
                  ),
                  _InfoLine(
                    Icons.lock_clock_rounded,
                    'Rings full-screen over the lock screen. Snooze and '
                    'Dismiss follow what you chose for each prayer.',
                  ),
                  _InfoLine(
                    Icons.battery_saver_rounded,
                    'Needs notifications, full-screen alerts and a battery '
                    'optimisation exemption, or Android may delay an alarm.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String message;

  const _StatusLine({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(top: 12.h),
    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14.r),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17.sp, color: color),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.4,
              color: AppColors.inkText,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 10.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16.sp, color: AppColors.textMuted),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/permissions/widgets/permission_request_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../data/prayer_dnd_channel.dart';
import '../../domain/dnd_settings.dart';
import '../providers/prayer_dnd_provider.dart';
import '../widgets/dnd_duration_section.dart';

/// Do Not Disturb during prayer. Android needs a special "Notification Policy
/// access" grant that can only be given in system settings, so enabling is a
/// two-step flow: explain → send the user to settings → finish enabling when
/// they come back and access is actually granted.
class PrayerDndScreen extends ConsumerStatefulWidget {
  const PrayerDndScreen({super.key});

  @override
  ConsumerState<PrayerDndScreen> createState() => _PrayerDndScreenState();
}

class _PrayerDndScreenState extends ConsumerState<PrayerDndScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _awaitingPolicyAccess = false;
  bool? _hasPolicyAccess;
  bool _exactAlarmsOk = true;
  String? _statusMessage;
  bool _statusIsError = false;
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 120 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _bar.value) _bar.value = t;
    });
    _refreshAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _onReturnedFromSettings();
  }

  Future<void> _refreshAccess() async {
    final channel = ref.read(prayerDndChannelProvider);
    final granted = await channel.hasPolicyAccess();
    final exact = await channel.canScheduleExactAlarms();
    if (mounted) {
      setState(() {
        _hasPolicyAccess = granted;
        _exactAlarmsOk = exact;
      });
    }
  }

  Future<void> _onReturnedFromSettings() async {
    await _refreshAccess();
    final settings = ref.read(dndSettingsProvider);
    if (_awaitingPolicyAccess && _hasPolicyAccess == true) {
      _awaitingPolicyAccess = false;
      await _enable();
    } else if (_hasPolicyAccess == false && settings.enabled) {
      // Access was revoked in system settings — the switch must not lie.
      await ref.read(dndSettingsProvider.notifier).setEnabled(false);
      await ref.read(prayerDndServiceProvider).cancelAll();
      _setStatus(
        'Do Not Disturb access was turned off in system settings, so the '
        'feature has been switched off.',
        true,
      );
    }
  }

  Future<void> _onToggle(bool enabled) async {
    if (_busy) return;
    final notifier = ref.read(dndSettingsProvider.notifier);
    final channel = ref.read(prayerDndChannelProvider);

    if (enabled && defaultTargetPlatform != TargetPlatform.android) {
      _setStatus(
        'Do Not Disturb can only be switched on automatically on Android. '
        'iOS doesn’t let apps change Focus modes.',
        true,
      );
      return;
    }

    if (!enabled) {
      await notifier.setEnabled(false);
      await ref.read(prayerDndServiceProvider).cancelAll();
      _setStatus('Turned off. Your phone will no longer be silenced.', false);
      return;
    }

    if (!await channel.hasPolicyAccess()) {
      if (!mounted) return;
      final proceed = await showPermissionRequestSheet(
        context,
        icon: Icons.do_not_disturb_on_outlined,
        title: 'Allow Do Not Disturb access',
        rationale:
            'Android only lets an app change Do Not Disturb after you allow '
            'it in Settings. On the next screen, find Deen and switch it on, '
            'then come back. Deen only uses this to silence calls and '
            'notifications during prayer, and switches it off afterwards.',
        actionLabel: 'Open settings',
      );
      if (!mounted || !proceed) return;
      _awaitingPolicyAccess = true;
      await channel.openPolicyAccessSettings();
      return;
    }
    await _enable();
  }

  Future<void> _enable() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final notifier = ref.read(dndSettingsProvider.notifier);
      final channel = ref.read(prayerDndChannelProvider);

      await notifier.setEnabled(true);
      final result = await ref.read(prayerDndServiceProvider).sync();
      switch (result) {
        case DndSyncScheduled(:final windowCount):
          _setStatus(
            'On — $windowCount upcoming prayer windows scheduled. This keeps '
            'working with the app closed.',
            false,
          );
        case DndSyncNothingConfigured():
          _setStatus(
            'Auto Do Not Disturb is on. Set a duration for at least one '
            'prayer below.',
            false,
          );
        case DndSyncFailed(:final message):
          await notifier.setEnabled(false);
          _setStatus(message, true);
          return;
        case DndSyncDisabled():
          break;
      }

      // Not blocking: without exact alarms Android may start DND a few
      // minutes late, which is worth knowing but not worth refusing over.
      if (!await channel.canScheduleExactAlarms()) {
        if (!mounted) return;
        final proceed = await showPermissionRequestSheet(
          context,
          icon: Icons.alarm_on_rounded,
          title: 'Start exactly on time',
          rationale:
              'Allow "Alarms & reminders" so Do Not Disturb starts at the '
              'exact minute the prayer begins. Without it, Android may start '
              'it a few minutes late.',
          actionLabel: 'Open settings',
        );
        if (proceed) await channel.openExactAlarmSettings();
        await _refreshAccess();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Re-arms after a preference change; a no-op while the feature is off.
  Future<void> _resync() async {
    final result = await ref.read(prayerDndServiceProvider).syncIfEnabled();
    switch (result) {
      case DndSyncFailed(:final message):
        _setStatus(message, true);
      case DndSyncScheduled(:final windowCount):
        _setStatus('Saved — $windowCount upcoming windows scheduled.', false);
      case DndSyncNothingConfigured():
        _setStatus(
          'Nothing scheduled yet. Set a duration for at least one prayer.',
          false,
        );
      case DndSyncDisabled():
        break;
    }
  }

  void _setStatus(String message, bool isError) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(dndSettingsProvider);
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            ListView(
              controller: _scroll,
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              children: [
                _hero(settings),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSize(
                        duration: context.motion.duration(AppMotion.normal),
                        curve: AppMotion.entrance,
                        alignment: Alignment.topCenter,
                        child: _busy
                            ? Padding(
                                padding: EdgeInsets.only(top: 16.h),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4.r),
                                  child: LinearProgressIndicator(
                                    color: AppColors.gold,
                                    backgroundColor: AppColors.borderWarm,
                                  ),
                                ),
                              )
                            : _statusMessage != null
                            ? Padding(
                                padding: EdgeInsets.only(top: 16.h),
                                child: _StatusBanner(
                                  message: _statusMessage!,
                                  isError: _statusIsError,
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      SizedBox(height: 22.h),
                      _timelinePreview(settings).slideIn(
                        RevealDirection.bottomStart,
                        delay: const Duration(milliseconds: 200),
                      ),
                      ExpandSection(
                        expanded: settings.enabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_exactAlarmsOk) _exactAlarmNotice(),
                            _section(
                              'How long should it stay on?',
                              Icons.timer_rounded,
                              trailing: '${settings.configuredCount} of 5 set',
                            ),
                            DndDurationSection(onChanged: _resync),
                          ],
                        ),
                      ),
                      _section('Good to know', Icons.lightbulb_outline_rounded),
                      const _InfoRow(
                        icon: Icons.alarm_rounded,
                        title: 'Alarms still ring',
                        body:
                            'Only calls, messages and notifications are silenced, so your '
                            'wake-up alarm and prayer alarm won’t be missed.',
                      ).slideIn(RevealDirection.start, onVisible: true),
                      const _InfoRow(
                        icon: Icons.person_outline_rounded,
                        title: 'Your own settings are respected',
                        body:
                            'If Do Not Disturb is already on, Deen leaves it alone, and it '
                            'never switches off a mode you turned on yourself.',
                      ).slideIn(RevealDirection.end, onVisible: true),
                      const _InfoRow(
                        icon: Icons.offline_bolt_outlined,
                        title: 'Works offline',
                        body:
                            'Four weeks of prayers are scheduled ahead of time, using the same '
                            'calculation method as your prayer times.',
                      ).slideIn(RevealDirection.bottomStart, onVisible: true),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(
                opacity: _bar,
                title: 'Prayer Do Not Disturb',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero with the master switch ───────────────────────────────────────

  Widget _hero(DndSettings settings) {
    final on = settings.enabled;
    final needsAccess = _hasPolicyAccess == false;
    return AnimatedContainer(
      duration: context.motion.duration(AppMotion.value),
      curve: AppMotion.standard,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: on
              ? [const Color(0xFF0B1B2B), const Color(0xFF1C3550)]
              : [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.07),
              cell: 52,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + 66.h,
              24.w,
              26.h,
            ),
            child: Column(
              children: [
                // Medallion
                SizedBox(
                  width: 120.w,
                  height: 120.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: context.motion.duration(AppMotion.slow),
                        width: 120.w,
                        height: 120.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.gold.withValues(alpha: on ? 0.35 : 0.0),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100.w,
                        height: 100.w,
                        child: CustomPaint(
                          painter: StarPainter(
                            fill: on
                                ? AppColors.gold.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.08),
                            stroke: on
                                ? AppColors.goldLight
                                : Colors.white.withValues(alpha: 0.35),
                            strokeWidth: 1.6,
                            inner: 0.76,
                          ),
                          child: IconSwap(
                            child: Icon(
                              on
                                  ? Icons.notifications_off_rounded
                                  : Icons.notifications_active_outlined,
                              key: ValueKey(on),
                              size: 38.sp,
                              color: on ? AppColors.goldLight : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).slideIn(RevealDirection.top, distance: 20),
                SizedBox(height: 14.h),
                AnimatedText(
                  on ? 'Silent during prayer' : 'Silence your phone for prayer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ).slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 60),
                ),
                SizedBox(height: 8.h),
                Text(
                  on
                      ? 'Do Not Disturb turns on when each selected prayer begins, then switches off again.'
                      : 'When a prayer begins, Deen turns on Do Not Disturb so calls and notifications don’t interrupt you — then switches it off.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.5,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.78),
                  ),
                ).slideIn(
                  RevealDirection.top,
                  delay: const Duration(milliseconds: 120),
                ),
                SizedBox(height: 20.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: on
                          ? AppColors.gold.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto Do Not Disturb',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            AnimatedText(
                              needsAccess && !on
                                  ? 'Needs permission to start'
                                  : on
                                  ? 'On · starts with each prayer'
                                  : 'Off',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: on
                                    ? AppColors.goldLight
                                    : Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: on,
                        onChanged: _busy ? null : _onToggle,
                        activeThumbColor: AppColors.heroSurface,
                        activeTrackColor: AppColors.gold,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ],
                  ),
                ).slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 180),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeline preview ──────────────────────────────────────────────────

  Widget _timelinePreview(DndSettings s) {
    final duration = s.configuredCount == 0
        ? 'once you set a duration for a prayer'
        : 'for the time you set for each prayer';
    Widget node(IconData icon, String label, {bool gold = false}) {
      return Column(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gold ? AppColors.gold : AppColors.heroSurface,
            ),
            child: Icon(
              icon,
              size: 20.sp,
              color: gold ? AppColors.heroSurface : AppColors.goldLight,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.inkText,
            ),
          ),
        ],
      );
    }

    Widget line() => Expanded(
      child: Padding(
        padding: EdgeInsets.only(bottom: 22.h),
        child: Container(
          height: 2,
          color: AppColors.gold.withValues(alpha: 0.5),
        ),
      ),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What will happen',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              node(Icons.mosque_rounded, 'Prayer begins'),
              line(),
              node(Icons.notifications_off_rounded, 'Silent', gold: true),
              line(),
              node(Icons.notifications_active_rounded, 'Back to normal'),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Your phone stays silent $duration.',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Building blocks ───────────────────────────────────────────────────

  Widget _section(String title, IconData icon, {String? trailing}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 26.h, 0, 12.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppColors.gold).slideIn(
            RevealDirection.bottomStart,
            onVisible: true,
            distance: 16,
            duration: AppMotion.normal,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child:
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ).slideIn(
                  RevealDirection.start,
                  onVisible: true,
                  delay: const Duration(milliseconds: 50),
                ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
            ).slideIn(
              RevealDirection.topEnd,
              onVisible: true,
              delay: const Duration(milliseconds: 100),
              duration: AppMotion.normal,
              distance: 16,
            ),
        ],
      ),
    );
  }

  Widget _exactAlarmNotice() {
    return Padding(
      padding: EdgeInsets.only(top: 22.h),
      child: _StatusBanner(
        message:
            'Exact timing is off, so Android may start Do Not Disturb a few '
            'minutes late.',
        isError: true,
        actionLabel: 'Allow',
        onAction: () async {
          await ref.read(prayerDndChannelProvider).openExactAlarmSettings();
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: child,
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _StatusBanner({
    required this.message,
    required this.isError,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isError ? AppColors.hadithAccentBg : AppColors.quranAccentBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: (isError ? AppColors.error : AppColors.quranAccent).withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18.sp,
            color: isError ? AppColors.error : AppColors.quranAccent,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.45,
                color: AppColors.inkText,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoRow({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: _Card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(9.w),
              decoration: BoxDecoration(
                color: AppColors.toolsAccentBg,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, size: 18.sp, color: AppColors.toolsAccent),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkText,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12.sp,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_status.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../daily_content/presentation/providers/daily_content_providers.dart';
import '../../../islamic_calendar/presentation/providers/islamic_calendar_providers.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';
import '../providers/day_phase_provider.dart';
import '../providers/home_provider.dart';

const _prayerLabels = {
  PrayerName.fajr: 'Fajr',
  PrayerName.dhuhr: 'Dhuhr',
  PrayerName.asr: 'Asr',
  PrayerName.maghrib: 'Maghrib',
  PrayerName.isha: 'Isha',
};

/// The room the rounded top of the content takes at the bottom of the header
/// while it is fully open.
const double _lipHeight = 40;

/// The time-of-day GIF backdrop + greeting + date/location + next-prayer
/// summary at the top of Home. Self-contained: the backdrop follows
/// [dayPhaseProvider] and the header reads every
/// piece of real data (Hijri date, location, next prayer) itself.
///
/// It is built to collapse. [collapse] runs from 0 (fully open, as Home
/// opens) to 1 (the slim bar kept at the top while the page scrolls): the big
/// summary fades out, a compact "Next: Maghrib in 1h 14m" pill takes its
/// place, and the bell stays put. [height] is the height drawn right now, and
/// the content keeps the layout it has at [expandedHeight], clipped as the
/// header shrinks, so nothing reflows while it moves.
class HomeSliderHeader extends ConsumerStatefulWidget {
  final double height;
  final double expandedHeight;
  final double collapse;
  final VoidCallback onAvatarTap;

  const HomeSliderHeader({
    super.key,
    required this.height,
    required this.onAvatarTap,
    double? expandedHeight,
    this.collapse = 0,
  }) : expandedHeight = expandedHeight ?? height;

  @override
  ConsumerState<HomeSliderHeader> createState() => _HomeSliderHeaderState();
}

class _HomeSliderHeaderState extends ConsumerState<HomeSliderHeader> {
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 20) return 'Good Evening';
    return 'Good Night';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.collapse.clamp(0.0, 1.0);
    final safeTop = MediaQuery.paddingOf(context).top;
    // The big summary is gone by 60% closed and the compact pill is in by
    // 80%; the two overlap in between, so the header is never empty.
    final openFade = (1 - t / 0.6).clamp(0.0, 1.0);
    final barFade = ((t - 0.4) / 0.4).clamp(0.0, 1.0);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _DayPhaseBackdrop(period: ref.watch(dayPhaseProvider)),
          // Darker as it closes, so the slim bar reads clearly over the GIF.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55 + 0.3 * t),
                  Colors.black.withValues(alpha: 0.35 + 0.5 * t),
                  Colors.black.withValues(alpha: 0.75 + 0.15 * t),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          // The full summary. It keeps its open-state layout and is clipped
          // by the shrinking header, fading as it goes.
          Positioned.fill(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: widget.expandedHeight,
                maxHeight: widget.expandedHeight,
                child: IgnorePointer(
                  ignoring: openFade < 0.5,
                  child: Opacity(
                    opacity: openFade,
                    child: Transform.translate(
                      offset: Offset(0, -28.h * t),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 10.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _greeting,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ).slideIn(
                                          RevealDirection.topStart,
                                          fade: false,
                                        ),
                                        SizedBox(height: 4.h),
                                        _HijriDateLine().slideIn(
                                          RevealDirection.start,
                                          delay: const Duration(
                                            milliseconds: 70,
                                          ),
                                          fade: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Where the bell is (it is drawn separately,
                                  // below, so it stays through the collapse).
                                  SizedBox(width: 44.h, height: 44.h),
                                ],
                              ),
                              SizedBox(height: 22.h),
                              _NextPrayerSummary(formatTime: _formatTime),
                              SizedBox(height: 22.h),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _LocationLine().slideIn(
                                    RevealDirection.bottomStart,
                                    delay: const Duration(milliseconds: 300),
                                    fade: false,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The slim bar's content: the next prayer, in one line.
          Positioned(
            left: 18.w,
            right: 18.w + 44.h + 12.w,
            top: safeTop + 10.h,
            height: 44.h,
            child: IgnorePointer(
              ignoring: barFade < 0.5,
              child: Opacity(
                opacity: barFade,
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: _CompactNextPrayer(),
                ),
              ),
            ),
          ),
          // The bell: in the same place open and closed.
          Positioned(
            top: safeTop + 10.h,
            right: 18.w,
            child:
                Pressable(
                  onTap: () => context.push('/notifications'),
                  scale: AppMotion.pressScaleSmall,
                  child: Container(
                    height: 44.h,
                    width: 44.h,
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                        if (ref.watch(unreadNotificationCountProvider) > 0)
                          Positioned(
                            top: 9.h,
                            right: 10.w,
                            child: Container(
                              width: 10.w,
                              height: 10.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ).slideIn(
                  RevealDirection.topEnd,
                  delay: const Duration(milliseconds: 40),
                  fade: false,
                ),
          ),
          // The rounded top of the page content. It is part of the header so
          // the content below can simply continue from the header's edge; it
          // folds away as the header closes into the flat slim bar.
          if (t < 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _lipHeight.h * (1 - t),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.parchment,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30.r),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rebuilds [builder] on every minute change of the phone's clock, so a
/// countdown flips together with it instead of drifting behind.
class _MinuteBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, DateTime now) builder;
  const _MinuteBuilder({required this.builder});

  @override
  State<_MinuteBuilder> createState() => _MinuteBuilderState();
}

class _MinuteBuilderState extends State<_MinuteBuilder> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final untilNextMinute =
        Duration(seconds: 60 - now.second) -
        Duration(milliseconds: now.millisecond);
    _timer = Timer(untilNextMinute + const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

/// "Next: Maghrib in 1h 14m", the one line the slim bar keeps. The same real
/// lookup as the big summary ([PrayerTimes.nextPrayer]).
class _CompactNextPrayer extends ConsumerWidget {
  const _CompactNextPrayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final times = ref.watch(prayerTimesNotifierProvider).valueOrNull;
    if (times == null) return const SizedBox.shrink();
    return _MinuteBuilder(
      builder: (context, now) {
        final next = times.nextPrayer(now);
        final left = times.timeUntilNextPrayer(now);
        final hours = left.inHours;
        final minutes = left.inMinutes.remainder(60);
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: AppColors.emeraldInk.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 15.sp,
              ),
              SizedBox(width: 7.w),
              Flexible(
                child: Text(
                  'Next: ${_prayerLabels[next.key]} in '
                  '${hours > 0 ? '${hours}h ' : ''}${minutes}m',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pins the header and shrinks it from [expandedHeight] to [collapsedHeight]
/// as the page scrolls, telling [builder] how far it has closed (0 to 1).
class HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double expandedHeight;
  final double collapsedHeight;
  final Widget Function(BuildContext context, double height, double collapse)
  builder;

  const HomeHeaderDelegate({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.builder,
  });

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = expandedHeight - collapsedHeight;
    final t = range <= 0 ? 0.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    return builder(context, expandedHeight - shrinkOffset.clamp(0, range), t);
  }

  @override
  bool shouldRebuild(HomeHeaderDelegate old) =>
      old.expandedHeight != expandedHeight ||
      old.collapsedHeight != collapsedHeight ||
      old.builder != builder;
}

/// Full-bleed GIF for the current [DayPhase], cross-fading when it changes.
class _DayPhaseBackdrop extends StatelessWidget {
  final DayPhase period;
  const _DayPhaseBackdrop({required this.period});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion.duration(AppMotion.slow),
      child: Image.asset(
        period.gifAsset,
        key: ValueKey(period),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      ),
    );
  }
}

/// "5:49 PM" with the AM/PM set smaller and in the app's orange.
class _ClockText extends StatelessWidget {
  final DateTime time;
  final double size;
  final FontWeight weight;

  const _ClockText({
    required this.time,
    required this.size,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$hour:$minute ',
            style: TextStyle(
              color: Colors.white,
              fontSize: size,
              fontWeight: weight,
              height: 1.05,
              // Fixed-width digits, so the ticking seconds don't jiggle.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(
            text: period,
            style: TextStyle(
              color: AppColors.emeraldInk,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// The user's points in the star frame the Profile avatar uses.
class _PointsBadge extends ConsumerWidget {
  const _PointsBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      authSessionProvider.select((s) => s.isAuthenticated),
    );
    final total = signedIn
        ? ref.watch(myPointsProvider).valueOrNull?.total
        : null;
    final frame = 76.w;
    return Semantics(
      label: total == null ? 'Points' : '$total points',
      excludeSemantics: true,
      child: SizedBox(
        width: frame,
        height: frame,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(frame),
              painter: StarPainter(
                fill: Colors.transparent,
                stroke: AppColors.goldLight,
                strokeWidth: 1.4,
                inner: 0.8,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  total == null ? '–' : '$total',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: AppColors.goldLight,
                  ),
                ),
                Text(
                  'Points',
                  style: TextStyle(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight.withValues(alpha: 0.85),
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

class _HijriDateLine extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayHijriAsync = ref.watch(todayHijriNotifierProvider);
    return todayHijriAsync.when(
      data: (today) => Text(
        today.hijri.formatted,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      loading: () => Text(
        'Loading date…',
        style: TextStyle(color: Colors.white70, fontSize: 15.sp),
      ),
      error: (_, _) => Pressable(
        onTap: () => ref.invalidate(todayHijriNotifierProvider),
        child: Text(
          'Date unavailable · Retry',
          style: TextStyle(color: Colors.white70, fontSize: 13.sp),
        ),
      ),
    );
  }
}

/// Chip + big clock, both driven by the same real next-prayer lookup used
/// elsewhere in the app ([PrayerTimes.nextPrayer]/[timeUntilNextPrayer]) —
/// this is the *upcoming* prayer, not "the one currently in progress" (the
/// app has no separate notion of a prayer's active window yet).
class _NextPrayerSummary extends ConsumerStatefulWidget {
  final String Function(DateTime) formatTime;
  const _NextPrayerSummary({required this.formatTime});

  @override
  ConsumerState<_NextPrayerSummary> createState() => _NextPrayerSummaryState();
}

class _NextPrayerSummaryState extends ConsumerState<_NextPrayerSummary> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  /// Fires exactly on each minute change, so the displayed time and the
  /// countdown flip together with the phone's own clock instead of drifting
  /// up to a minute behind it.
  void _scheduleTick() {
    final now = DateTime.now();
    final untilNextMinute =
        Duration(seconds: 60 - now.second) -
        Duration(milliseconds: now.millisecond);
    _ticker = Timer(untilNextMinute + const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayerTimesAsync = ref.watch(prayerTimesNotifierProvider);

    return prayerTimesAsync.when(
      data: (prayerTimes) {
        final next = prayerTimes.nextPrayer(_now);
        final timeLeft = prayerTimes.timeUntilNextPrayer(_now);
        final hours = timeLeft.inHours;
        final minutes = timeLeft.inMinutes.remainder(60);
        final label = _prayerLabels[next.key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.emeraldInk.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 13.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Next: $label in ${hours > 0 ? '${hours}h ' : ''}${minutes}m',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ).slideIn(
              RevealDirection.bottomStart,
              delay: const Duration(milliseconds: 100),
              duration: AppMotion.normal,
              fade: false,
            ),
            SizedBox(height: 12.h),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ).slideIn(
              RevealDirection.start,
              delay: const Duration(milliseconds: 160),
              duration: AppMotion.normal,
              fade: false,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ClockText(
                  time: next.value,
                  size: 46.sp,
                  weight: FontWeight.bold,
                ),
                const Spacer(),
                // The user's points, in the same star frame as the Profile
                // avatar.
                const _PointsBadge(),
              ],
            ).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 220),
              fade: false,
              distance: 18,
            ),
          ],
        );
      },
      loading: () => SizedBox(
        height: 90.h,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ),
      error: (error, _) {
        // A location problem gets the action that actually fixes it; once
        // it's fixed the provider rebuilds by itself (locationRecoveryProvider),
        // so this state disappears without another tap.
        final kind = error is LocationFailure ? error.kind : null;
        final actionable =
            kind != null && (kind.isRequestable || kind.needsSystemSettings);
        return Pressable(
          onTap: () async {
            if (actionable) {
              await resolveLocationIssue(
                ref.read(locationServiceProvider),
                kind,
              );
            } else {
              await ref.read(prayerTimesNotifierProvider.notifier).refresh();
            }
          },
          child: Text(switch (kind) {
            LocationErrorKind.serviceDisabled =>
              'Turn on location for prayer times',
            LocationErrorKind.permissionDenied ||
            LocationErrorKind.permissionDeniedForever =>
              'Allow location for prayer times',
            _ => 'Prayer times unavailable · Retry',
          }, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
        );
      },
    );
  }
}

class _LocationLine extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(currentLocationNameProvider);
    final style = TextStyle(
      color: Colors.white,
      fontSize: 13.sp,
      fontWeight: FontWeight.w600,
    );

    return locationAsync.when(
      loading: () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10.w,
            height: 10.w,
            child: const CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white70,
            ),
          ),
          SizedBox(width: 6.w),
          Text('Locating…', style: style.copyWith(color: Colors.white70)),
        ],
      ),
      error: (_, _) => Pressable(
        onTap: () => ref.invalidate(currentLocationNameProvider),
        child: Text('Location unavailable · Retry', style: style),
      ),
      data: (label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, color: Colors.white70, size: 14.sp),
          SizedBox(width: 4.w),
          Flexible(
            child: switch (label) {
              LocationLabelResolved(:final name) => Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
              LocationLabelUnavailable(:final kind) => Pressable(
                onTap: () async {
                  await resolveLocationIssue(
                    ref.read(locationServiceProvider),
                    kind,
                  );
                  ref.invalidate(currentLocationNameProvider);
                },
                child: Text(
                  kind.isRequestable || kind.needsSystemSettings
                      ? 'Enable location'
                      : 'Location unavailable · Retry',
                  style: style,
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

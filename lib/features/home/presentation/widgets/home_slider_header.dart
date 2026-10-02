import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_status.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../daily_content/presentation/providers/daily_content_providers.dart';
import '../../../islamic_calendar/presentation/providers/islamic_calendar_providers.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';
import '../providers/home_provider.dart';

const _prayerLabels = {
  PrayerName.fajr: 'Fajr',
  PrayerName.dhuhr: 'Dhuhr',
  PrayerName.asr: 'Asr',
  PrayerName.maghrib: 'Maghrib',
  PrayerName.isha: 'Isha',
};

const List<String> _sliderImages = [
  'assets/images/slider_1.jpg',
  'assets/images/slider_2.jpg',
  'assets/images/slider_3.jpg',
  'assets/images/slider_4.jpg',
  'assets/images/slider_5.jpg',
];

/// The image slider + greeting + date/location + next-prayer summary at the
/// top of Home. Self-contained: owns its own slide timer and reads every
/// piece of real data (Hijri date, location, next prayer) itself, so the
/// screen that hosts it only needs to give it a height and a tap target for
/// the avatar.
class HomeSliderHeader extends ConsumerStatefulWidget {
  final double height;
  final VoidCallback onAvatarTap;

  const HomeSliderHeader({
    super.key,
    required this.height,
    required this.onAvatarTap,
  });

  @override
  ConsumerState<HomeSliderHeader> createState() => _HomeSliderHeaderState();
}

class _HomeSliderHeaderState extends ConsumerState<HomeSliderHeader> {
  late final PageController _pageController;
  Timer? _sliderTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_pageController.hasClients) return;
      final nextIndex = (_currentIndex + 1) % _sliderImages.length;
      _pageController.animateToPage(
        nextIndex,
        duration: context.motion.duration(AppMotion.value),
        curve: AppMotion.standard,
      );
    });
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

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
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _sliderImages.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) =>
                Image.asset(_sliderImages[index], fit: BoxFit.cover),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ).slideIn(RevealDirection.topStart, fade: false),
                            SizedBox(height: 4.h),
                            _HijriDateLine().slideIn(
                              RevealDirection.start,
                              delay: const Duration(milliseconds: 70),
                              fade: false,
                            ),
                          ],
                        ),
                      ),
                      Pressable(
                        onTap: () => context.push('/notifications'),
                        scale: AppMotion.pressScaleSmall,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14.r),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              height: 44.h,
                              width: 44.h,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 1.2.w,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    color: Colors.white,
                                    size: 22.sp,
                                  ),
                                  if (ref.watch(
                                        unreadNotificationCountProvider,
                                      ) >
                                      0)
                                    Positioned(
                                      top: 10.h,
                                      right: 11.w,
                                      child: Container(
                                        width: 9.w,
                                        height: 9.w,
                                        decoration: BoxDecoration(
                                          color: AppColors.emeraldInk,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).slideIn(
                        RevealDirection.topEnd,
                        delay: const Duration(milliseconds: 40),
                        fade: false,
                      ),
                    ],
                  ),
                  SizedBox(height: 22.h),
                  _NextPrayerSummary(formatTime: _formatTime),
                  SizedBox(height: 42.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _LocationLine().slideIn(
                        RevealDirection.bottomStart,
                        delay: const Duration(milliseconds: 300),
                        fade: false,
                      ),
                      Row(
                        children: List.generate(_sliderImages.length, (index) {
                          final isActive = _currentIndex == index;
                          return AnimatedContainer(
                            duration: context.motion.duration(AppMotion.fast),
                            curve: AppMotion.entrance,
                            margin: EdgeInsets.only(right: 5.w),
                            width: isActive ? 22.w : 6.w,
                            height: 5.h,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.emeraldInk
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                          );
                        }),
                      ).slideIn(
                        RevealDirection.bottomEnd,
                        delay: const Duration(milliseconds: 340),
                        distance: 16,
                      ),
                    ],
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

/// "5:49 PM" with the AM/PM set smaller and in the app's orange.
class _ClockText extends StatelessWidget {
  final DateTime time;
  final double size;
  final FontWeight weight;
  final bool showSeconds;

  const _ClockText({
    required this.time,
    required this.size,
    required this.weight,
    this.showSeconds = false,
  });

  @override
  Widget build(BuildContext context) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: showSeconds ? '$hour:$minute:$second ' : '$hour:$minute ',
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

/// "Now" clock with seconds, ticking on the second.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// Aligned to the real second boundary so it never skips or doubles a
  /// second against the phone's own clock.
  void _schedule() {
    final n = DateTime.now();
    _timer = Timer(Duration(milliseconds: 1000 - n.millisecond + 5), () {
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
  Widget build(BuildContext context) => _ClockText(
    time: _now,
    size: 20.sp,
    weight: FontWeight.w700,
    showSeconds: true,
  );
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
                    color: AppColors.onEmeraldInk,
                    size: 13.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Next: $label in ${hours > 0 ? '${hours}h ' : ''}${minutes}m',
                    style: TextStyle(
                      color: AppColors.onEmeraldInk,
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
                // Live clock, so the countdown above is easy to sanity-check
                // against the time it is right now.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Now',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                    // Own 1-second ticker, so only this clock repaints each
                    // second, not the whole prayer summary.
                    const _LiveClock(),
                  ],
                ),
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

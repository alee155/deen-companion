import 'dart:async';
import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/permissions/widgets/permission_request_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/prayer_times.dart';
import '../providers/prayer_calculation_settings_provider.dart';
import '../providers/prayer_times_provider.dart';
import '../widgets/monthly_prayer_calendar.dart';
import '../widgets/prayer_hero.dart';
import '../widgets/prayer_list.dart';
import '../widgets/prayer_settings_sheet.dart';

class PrayerTimesScreen extends ConsumerStatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  ConsumerState<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends ConsumerState<PrayerTimesScreen> {
  final _now = ValueNotifier<DateTime>(DateTime.now());
  final _scroll = ScrollController();
  final _barOpacity = ValueNotifier<double>(0);
  Timer? _ticker;
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _now.value = DateTime.now();
    });
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 160 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _barOpacity.value) _barOpacity.value = t;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeRequestLocation(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _now.dispose();
    _scroll.dispose();
    _barOpacity.dispose();
    super.dispose();
  }

  Future<void> _maybeRequestLocation() async {
    final availability = await ref
        .read(locationServiceProvider)
        .checkAvailability();
    if (!mounted) return;
    if (availability.hasPermission || availability.permanentlyDenied) return;

    final proceed = await showPermissionRequestSheet(
      context,
      icon: Icons.my_location_rounded,
      title: 'Prayer times for where you are',
      rationale:
          'Deen calculates prayer times and the Qibla direction from your '
          'coordinates. Without it, times default to nothing at all — we '
          "never guess a city for you.",
      actionLabel: 'Allow location',
    );
    if (!mounted || !proceed) return;

    await ref.read(locationServiceProvider).requestPermission();
    ref.invalidate(locationAvailabilityProvider);
    if (!mounted) return;
    await ref.read(prayerTimesNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(prayerTimesNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            RefreshIndicator(
              edgeOffset: 90.h,
              onRefresh: () =>
                  ref.read(prayerTimesNotifierProvider.notifier).refresh(),
              child: CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  ...async.when(
                    data: (times) => _dataSlivers(times),
                    loading: _loadingSlivers,
                    error: (error, _) => _errorSlivers(error),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 32.h,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: _fixedBar()),
          ],
        ),
      ),
    );
  }

  // ── Fixed bar ─────────────────────────────────────────────────────────

  Widget _fixedBar() {
    return ValueListenableBuilder<double>(
      valueListenable: _barOpacity,
      builder: (context, raw, _) {
        final t = (raw * 2.5).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.heroSurface.withValues(alpha: t),
            boxShadow: t > 0.6
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18 * t),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 8.h),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    strength: t,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Prayer Times',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.tune_rounded,
                    strength: t,
                    tooltip: 'Prayer settings',
                    onPressed: () => showPrayerSettingsSheet(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Slivers ───────────────────────────────────────────────────────────

  List<Widget> _dataSlivers(PrayerTimes times) {
    final settings = ref.watch(prayerCalculationSettingsProvider);
    return [
      SliverToBoxAdapter(
        child: PrayerHero(times: times, now: _now),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
          child: Row(
            children: [
              _action(
                Icons.notifications_active_rounded,
                'Reminders',
                () => context.push('/reminders'),
                RevealDirection.bottomStart,
                0,
              ),
              SizedBox(width: 10.w),
              _action(
                Icons.explore_rounded,
                'Qibla',
                () => context.push('/qibla'),
                RevealDirection.bottom,
                60,
              ),
              // SizedBox(width: 10.w),
              // _action(
              //   Icons.tune_rounded,
              //   'Settings',
              //   () => showPrayerSettingsSheet(context),
              //   RevealDirection.bottomEnd,
              //   120,
              // ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 12.h),
          child: Row(
            children: [
              Expanded(
                child:
                    Text(
                      "Today's prayers",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ).slideIn(
                      RevealDirection.bottomStart,
                      onVisible: true,
                      delay: const Duration(milliseconds: 260),
                    ),
              ),
              Pressable(
                scale: AppMotion.pressScaleSmall,
                onTap: () => showPrayerSettingsSheet(context),
                child: Container(
                  constraints: BoxConstraints(maxWidth: 170.w),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.toolsAccentBg,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    settings.method.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.toolsAccent,
                    ),
                  ),
                ),
              ).slideIn(
                RevealDirection.topEnd,
                onVisible: true,
                delay: const Duration(milliseconds: 300),
                duration: AppMotion.normal,
                distance: 16,
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        sliver: SliverToBoxAdapter(
          child: PrayerTimeline(times: times, now: _now),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
          child: const BannerAdWidget(
            margin: EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
          child: Column(
            children: [
              PressScale(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20.r),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showCalendar = !_showCalendar);
                  },
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.borderWarm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: AppColors.emeraldInk,
                          size: 22.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly calendar',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkText,
                                ),
                              ),
                              Text(
                                'Plan ahead with every day of the month',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _showCalendar ? 0.5 : 0,
                          duration: context.motion.duration(AppMotion.fast),
                          curve: AppMotion.entrance,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).slideIn(RevealDirection.bottom, onVisible: true),
              AnimatedSize(
                duration: context.motion.duration(AppMotion.normal),
                curve: AppMotion.entrance,
                alignment: Alignment.topCenter,
                child: _showCalendar
                    ? Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: const MonthlyPrayerCalendar(),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onTap,
    RevealDirection dir,
    int ms,
  ) {
    return Expanded(
      child:
          PressScale(
            child: InkWell(
              borderRadius: BorderRadius.circular(18.r),
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: AppColors.borderWarm),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 22.sp, color: AppColors.emeraldInk),
                    SizedBox(height: 6.h),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).slideIn(
            dir,
            delay: Duration(milliseconds: 160 + ms),
            distance: 18,
            duration: AppMotion.normal,
          ),
    );
  }

  List<Widget> _loadingSlivers() {
    return [
      SliverToBoxAdapter(
        child: Container(
          height: 420.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
          ),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 0),
        sliver: SliverList.separated(
          itemCount: 5,
          separatorBuilder: (_, _) => SizedBox(height: 10.h),
          itemBuilder: (_, _) => ShimmerBox(
            width: double.infinity,
            height: 62.h,
            borderRadius: 20.r,
          ),
        ),
      ),
    ];
  }

  List<Widget> _errorSlivers(Object error) {
    return [
      SliverToBoxAdapter(
        child: Container(
          height: 150.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.all(20.w),
        sliver: SliverToBoxAdapter(
          child: FailureView(
            failure: failureFrom(error),
            onRetry: () =>
                ref.read(prayerTimesNotifierProvider.notifier).refresh(),
          ),
        ),
      ),
    ];
  }
}

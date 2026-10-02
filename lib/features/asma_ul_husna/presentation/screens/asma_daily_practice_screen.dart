import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/entities/asma_daily.dart';
import '../providers/asma_ul_husna_providers.dart';
import '../widgets/asma_ornaments.dart';

class AsmaDailyPracticeScreen extends ConsumerStatefulWidget {
  final int initialDay;
  const AsmaDailyPracticeScreen({super.key, required this.initialDay});

  @override
  ConsumerState<AsmaDailyPracticeScreen> createState() =>
      _AsmaDailyPracticeScreenState();
}

class _AsmaDailyPracticeScreenState
    extends ConsumerState<AsmaDailyPracticeScreen> {
  late int _selectedDay;
  late final int _today;
  PageController _controller = PageController();

  int _currentIndex = 0;
  int _count = 0;
  int _target = 3;
  int _totalTaps = 0;
  bool _completed = false;
  bool _advancing = false;
  final Set<int> _done = {};

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _targets = [1, 3, 7, 11, 33];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay;
    _today = DateTime.now().weekday;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetSession() {
    _currentIndex = 0;
    _count = 0;
    _totalTaps = 0;
    _completed = false;
    _advancing = false;
    _done.clear();
    _controller.dispose();
    _controller = PageController();
  }

  void _selectDay(int day) {
    if (day == _selectedDay) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDay = day;
      _resetSession();
    });
  }

  Future<void> _tap(AsmaDaily daily) async {
    if (_advancing || _completed) return;
    setState(() {
      _count++;
      _totalTaps++;
    });
    if (_count < _target) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _done.add(_currentIndex));
    _advancing = true;
    await Future<void>.delayed(AppMotion.slow);
    if (!mounted) return;
    _advancing = false;
    _next(daily);
  }

  void _next(AsmaDaily daily) {
    if (_currentIndex >= daily.names.length - 1) {
      setState(() => _completed = true);
      return;
    }
    _controller.nextPage(
      duration: context.motion.duration(AppMotion.slow),
      curve: AppMotion.emphasized,
    );
  }

  void _previous() {
    if (_currentIndex == 0) return;
    _controller.previousPage(
      duration: context.motion.duration(AppMotion.slow),
      curve: AppMotion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dailyAsync = ref.watch(asmaDailyNotifierProvider(_selectedDay));

    return Scaffold(
      backgroundColor: AppColors.heroSurface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: GeometricPattern(
                  color: AppColors.goldLight.withValues(alpha: 0.06),
                  cell: 56,
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _header(dailyAsync.valueOrNull),
                    _daySelector(),
                    Expanded(
                      child: dailyAsync.when(
                        data: (daily) => daily.names.isEmpty
                            ? _message('No names for this day yet.')
                            : ContentSwitcher(
                                duration: AppMotion.slow,
                                child: _completed
                                    ? _completionView(daily)
                                    : _session(daily),
                              ),
                        loading: () => Center(
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                          ),
                        ),
                        error: (error, _) => _message(error.toString()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: EdgeInsets.all(32.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.onHeroSurface.withValues(alpha: 0.8)),
      ),
    ),
  );

  Widget _header(AsmaDaily? daily) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'DAILY DHIKR',
                  style: TextStyle(
                    fontSize: 10.sp,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ).slideIn(RevealDirection.topStart, distance: 14),
                SizedBox(height: 2.h),
                Text(
                  daily?.dayName ?? _dayLabels[_selectedDay - 1],
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onHeroSurface,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 40.w),
        ],
      ),
    );
  }

  Widget _daySelector() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final day = i + 1;
          final selected = day == _selectedDay;
          return Pressable(
            scale: AppMotion.pressScaleSmall,
            onTap: () => _selectDay(day),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 42.w,
              padding: EdgeInsets.symmetric(vertical: 8.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                color: selected
                    ? AppColors.gold
                    : AppColors.onHeroSurface.withValues(alpha: 0.07),
                border: Border.all(
                  color: selected
                      ? AppColors.gold
                      : AppColors.onHeroSurface.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _dayLabels[i],
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.heroSurface
                          : AppColors.onHeroSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    width: 5.w,
                    height: 5.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: day == _today
                          ? (selected
                                ? AppColors.heroSurface
                                : AppColors.goldLight)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ).slideIn(
            RevealDirection.top,
            distance: 14,
            delay: Duration(milliseconds: 80 + i * 40),
          );
        }),
      ),
    );
  }

  // ── Live session ──────────────────────────────────────────────────────

  Widget _session(AsmaDaily daily) {
    final total = daily.names.length;
    return Column(
      key: ValueKey('session$_selectedDay'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
          child: Column(
            children: [
              // Segmented progress — one segment per Name.
              Row(
                children: List.generate(total, (i) {
                  final filled = _done.contains(i);
                  final active = i == _currentIndex;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: context.motion.duration(AppMotion.normal),
                      height: 4.h,
                      margin: EdgeInsets.symmetric(horizontal: 1.5.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2.r),
                        color: filled
                            ? AppColors.gold
                            : active
                            ? AppColors.gold.withValues(alpha: 0.5)
                            : AppColors.onHeroSurface.withValues(alpha: 0.14),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedText(
                    'Name ${_currentIndex + 1} of $total',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.onHeroSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  AnimatedText(
                    '${_done.length} done',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.goldLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() {
              _currentIndex = i;
              _count = _done.contains(i) ? _target : 0;
            }),
            itemBuilder: (context, index) =>
                _namePage(daily, index, index == _currentIndex),
          ),
        ),
        _controls(daily),
      ],
    );
  }

  Widget _namePage(AsmaDaily daily, int index, bool isCurrent) {
    final name = daily.names[index];
    final shown = isCurrent ? _count : (_done.contains(index) ? _target : 0);
    final progress = (shown / _target).clamp(0.0, 1.0);
    final complete = _done.contains(index) && shown >= _target;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dial = (constraints.maxHeight * 0.52).clamp(190.0, 300.0);
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Pressable(
                  behavior: HitTestBehavior.opaque,
                  onTap: isCurrent ? () => _tap(daily) : null,
                  child: SizedBox(
                    width: dial,
                    height: dial,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: progress),
                          duration: context.motion.duration(AppMotion.fast),
                          curve: AppMotion.entrance,
                          builder: (_, v, _) => CustomPaint(
                            size: Size.square(dial),
                            painter: RingPainter(
                              progress: v,
                              track: AppColors.onHeroSurface.withValues(
                                alpha: 0.12,
                              ),
                              color: AppColors.gold,
                              width: 6,
                            ),
                          ),
                        ),
                        AnimatedScale(
                          scale: complete ? 1.05 : 1,
                          duration: context.motion.duration(AppMotion.normal),
                          curve: AppMotion.pop,
                          child: SizedBox(
                            width: dial - 30,
                            height: dial - 30,
                            child: CustomPaint(
                              painter: StarPainter(
                                fill: complete
                                    ? AppColors.gold.withValues(alpha: 0.22)
                                    : AppColors.onHeroSurface.withValues(
                                        alpha: 0.07,
                                      ),
                                stroke: AppColors.goldLight.withValues(
                                  alpha: complete ? 1 : 0.55,
                                ),
                                strokeWidth: 1.4,
                                inner: 0.78,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: dial * 0.17,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      name.arabic,
                                      textDirection: TextDirection.rtl,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontFamily: kAsmaArabicFont,
                                        fontSize: 54.sp,
                                        color: AppColors.goldLight,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  name.transliteration,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onHeroSurface,
                  ),
                ).slideIn(
                  RevealDirection.bottomStart,
                  delay: const Duration(milliseconds: 80),
                ),
                SizedBox(height: 2.h),
                Text(
                  name.english,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.w600,
                  ),
                ).slideIn(
                  RevealDirection.bottomEnd,
                  delay: const Duration(milliseconds: 140),
                ),
                SizedBox(height: 10.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Text(
                    name.meaning,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      height: 1.55,
                      color: AppColors.onHeroSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ).slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 200),
                ),
                SizedBox(height: 14.h),
                Text(
                  complete
                      ? 'Recited $_target× ✓'
                      : 'Tap the Name to recite  ·  $shown / $_target',
                  style: TextStyle(
                    fontSize: 12.sp,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w600,
                    color: complete
                        ? AppColors.gold
                        : AppColors.onHeroSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _controls(AsmaDaily daily) {
    final isLast = _currentIndex == daily.names.length - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 16.h),
      child: Column(
        children: [
          // Repetitions per Name.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Repeat',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.onHeroSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(width: 10.w),
              for (final t in _targets)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  child: Pressable(
                    scale: AppMotion.pressScaleSmall,
                    onTap: () => setState(() {
                      _target = t;
                      _count = _count.clamp(0, t);
                    }),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      width: 38.w,
                      height: 32.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        color: t == _target
                            ? AppColors.gold
                            : Colors.transparent,
                        border: Border.all(
                          color: t == _target
                              ? AppColors.gold
                              : AppColors.onHeroSurface.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '$t',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: t == _target
                              ? AppColors.heroSurface
                              : AppColors.onHeroSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ).slideIn(
            RevealDirection.bottomStart,
            delay: const Duration(milliseconds: 200),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              TextButton.icon(
                onPressed: _currentIndex == 0 ? null : _previous,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onHeroSurface,
                  disabledForegroundColor: AppColors.onHeroSurface.withValues(
                    alpha: 0.25,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _next(daily),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.heroSurface,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  isLast
                      ? 'Finish'
                      : (_done.contains(_currentIndex) ? 'Next' : 'Skip'),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ).slideIn(
                RevealDirection.bottomEnd,
                delay: const Duration(milliseconds: 260),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Completion ────────────────────────────────────────────────────────

  Widget _completionView(AsmaDaily daily) {
    final seq = RevealSequence(start: const Duration(milliseconds: 160));
    return SingleChildScrollView(
      key: const ValueKey('complete'),
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h),
      child: Column(
        children: [
          SizedBox(
            width: 140.w,
            height: 140.w,
            child: CustomPaint(
              painter: StarPainter(
                fill: AppColors.gold,
                stroke: AppColors.goldLight,
                strokeWidth: 2,
                inner: 0.75,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 64.sp,
                color: AppColors.heroSurface,
              ),
            ),
          ).celebrate(),
          SizedBox(height: 20.h),
          Text(
            'Dhikr complete',
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.onHeroSurface,
            ),
          ).slideIn(RevealDirection.top, delay: seq.next()),
          SizedBox(height: 4.h),
          Text(
            'بارك الله فيك',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: kAsmaArabicFont,
              fontSize: 24.sp,
              color: AppColors.goldLight,
            ),
          ).slideIn(RevealDirection.bottom, delay: seq.next()),
          SizedBox(height: 20.h),
          Row(
            children: [
              _stat(daily.names.length, 'Names'),
              SizedBox(width: 12.w),
              _stat(_totalTaps, 'Recitations'),
            ],
          ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppColors.onHeroSurface.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Text(
              daily.weeklyCompletion,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.5,
                color: AppColors.onHeroSurface.withValues(alpha: 0.8),
              ),
            ),
          ).slideIn(RevealDirection.end, delay: seq.next()),
          SizedBox(height: 16.h),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final n in daily.names)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    n.arabic,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: kAsmaArabicFont,
                      fontSize: 18.sp,
                      color: AppColors.goldLight,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ).slideIn(RevealDirection.topStart, delay: seq.next()),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(_resetSession),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.goldLight,
                    side: BorderSide(color: AppColors.gold),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: const Text('Go again'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.heroSurface,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ).slideIn(RevealDirection.bottom, delay: seq.next()),
        ],
      ),
    );
  }

  Widget _stat(int value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            AnimatedCount(
              value: value,
              fromZero: true,
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.goldLight,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.onHeroSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/warm_gradient_scaffold.dart';
import '../../domain/entities/asma_name.dart';
import '../providers/asma_ul_husna_providers.dart';
import '../widgets/asma_name_tile.dart';
import '../widgets/asma_ornaments.dart';
import 'asma_daily_practice_screen.dart';
import 'asma_detail_screen.dart';

enum _Range {
  all('All', 0, 999),
  first('1 – 33', 1, 33),
  second('34 – 66', 34, 66),
  third('67 – 99', 67, 99);

  final String label;
  final int from;
  final int to;
  const _Range(this.label, this.from, this.to);
}

class AsmaHubScreen extends ConsumerStatefulWidget {
  const AsmaHubScreen({super.key});

  @override
  ConsumerState<AsmaHubScreen> createState() => _AsmaHubScreenState();
}

class _AsmaHubScreenState extends ConsumerState<AsmaHubScreen> {
  _Range _range = _Range.all;
  bool _list = false;
  final _scroll = ScrollController();
  final _barOpacity = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 120 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _barOpacity.value) _barOpacity.value = t;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _barOpacity.dispose();
    super.dispose();
  }

  static const _dayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  void _openDetail(List<AsmaName> names, int index) {
    Navigator.of(context).push(
      asmaRoute((_) => AsmaDetailScreen(names: names, initialIndex: index)),
    );
  }

  void _openPractice(int day) {
    Navigator.of(
      context,
    ).push(asmaRoute((_) => AsmaDailyPracticeScreen(initialDay: day)));
  }

  @override
  Widget build(BuildContext context) {
    final namesAsync = ref.watch(asmaAllNamesNotifierProvider);
    final today = DateTime.now().weekday; // 1 = Monday … 7 = Sunday

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: WarmGradientBackground(
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _hero(namesAsync)),
                  SliverToBoxAdapter(child: _dhikrCard(today)),
                  SliverToBoxAdapter(child: _browseHeader()),
                  namesAsync.when(
                    data: (names) => _namesSliver(names),
                    loading: _loadingSliver,
                    error: (error, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32.w),
                        child: Center(
                          child: Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
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
              Positioned(top: 0, left: 0, right: 0, child: _fixedBar()),
            ],
          ),
        ),
      ),
    );
  }

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
                    child: Opacity(
                      opacity: t,
                      child: Text(
                        'أسماء الله الحسنى',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: kAsmaArabicFont,
                          fontSize: 22.sp,
                          color: AppColors.goldLight,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.search_rounded,
                    strength: t,
                    tooltip: 'Search by meaning',
                    onPressed: () => context.push('/asma-ul-husna/search'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────

  Widget _hero(AsyncValue<List<AsmaName>> namesAsync) {
    final seq = RevealSequence();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.09),
              cell: 52,
            ),
          ),
          // Soft golden glow behind the title.
          Positioned(
            top: -60.h,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260.w,
                height: 260.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
              child: Column(
                children: [
                  // Space for the fixed top bar.
                  SizedBox(height: 40.w),
                  SizedBox(height: 10.h),
                  Text(
                    'أسماء الله الحسنى',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: kAsmaArabicFont,
                      fontSize: 40.sp,
                      color: AppColors.goldLight,
                      height: 1.5,
                    ),
                  ).slideIn(RevealDirection.top, delay: seq.next()),
                  SizedBox(height: 2.h),
                  Text(
                    'The 99 Beautiful Names of Allah',
                    style: TextStyle(
                      fontSize: 13.sp,
                      letterSpacing: 0.4,
                      color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                    ),
                  ).slideIn(RevealDirection.bottom, delay: seq.next()),
                  SizedBox(height: 20.h),
                  namesAsync.when(
                    data: (names) => names.isEmpty
                        ? const SizedBox.shrink()
                        : _nameOfTheDay(names),
                    loading: () => ShimmerBox(
                      width: double.infinity,
                      height: 120.h,
                      borderRadius: 24.r,
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameOfTheDay(List<AsmaName> names) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final index = dayOfYear % names.length;
    final name = names[index];
    final seq = RevealSequence(start: const Duration(milliseconds: 140));

    return Pressable(
      onTap: () => _openDetail(names, index),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.onHeroSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96.w,
              height: 96.w,
              child: CustomPaint(
                painter: StarPainter(
                  fill: AppColors.gold.withValues(alpha: 0.14),
                  stroke: AppColors.goldLight,
                  strokeWidth: 1.2,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18.w),
                      child:
                          Text(
                            name.arabic,
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: kAsmaArabicFont,
                              fontSize: 30.sp,
                              color: AppColors.goldLight,
                              height: 1.4,
                            ),
                          ).slideIn(
                            RevealDirection.bottomStart,
                            delay: seq.next(),
                            distance: 16,
                          ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NAME OF THE DAY  ·  ${name.number}',
                    style: TextStyle(
                      fontSize: 10.sp,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ).slideIn(RevealDirection.topEnd, delay: seq.next()),
                  SizedBox(height: 4.h),
                  Text(
                    name.transliteration,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onHeroSurface,
                    ),
                  ).slideIn(RevealDirection.end, delay: seq.next()),
                  Text(
                    name.english,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                    ),
                  ).slideIn(RevealDirection.bottomEnd, delay: seq.next()),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Text(
                        'Reflect on it',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldLight,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14.sp,
                        color: AppColors.goldLight,
                      ),
                    ],
                  ).slideIn(RevealDirection.bottom, delay: seq.next()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Daily dhikr ───────────────────────────────────────────────────────

  Widget _dhikrCard(int today) {
    final seq = RevealSequence(start: const Duration(milliseconds: 200));
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
      child: Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.self_improvement_rounded,
                    size: 18.sp,
                    color: AppColors.gold,
                  ),
                ).slideIn(
                  RevealDirection.topStart,
                  delay: seq.next(),
                  distance: 16,
                  onVisible: true,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Dhikr',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                        ),
                      ).slideIn(
                        RevealDirection.top,
                        delay: seq.next(),
                        distance: 16,
                        onVisible: true,
                      ),
                      Text(
                        '15 names a day · all 99 across the week',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ).slideIn(
                        RevealDirection.bottomEnd,
                        delay: seq.next(),
                        onVisible: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = i + 1;
                final isToday = day == today;
                return Pressable(
                  scale: AppMotion.pressScaleSmall,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _openPractice(day);
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 38.w,
                    height: 48.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      color: isToday
                          ? AppColors.heroSurface
                          : Colors.transparent,
                      border: Border.all(
                        color: isToday ? AppColors.gold : AppColors.borderWarm,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _dayInitials[i],
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: isToday
                                ? AppColors.goldLight
                                : AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Container(
                          width: 5.w,
                          height: 5.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? AppColors.gold
                                : AppColors.borderWarm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).slideIn(
                  RevealDirection.bottom,
                  delay: Duration(milliseconds: 260 + i * 40),
                  distance: 14,
                  onVisible: true,
                );
              }),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openPractice(today),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.heroSurface,
                  foregroundColor: AppColors.goldLight,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  "Begin today's practice",
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 520),
              onVisible: true,
            ),
          ],
        ),
      ),
    );
  }

  // ── Browse ────────────────────────────────────────────────────────────

  Widget _browseHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 26.h, 20.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(
                      'Explore the Names',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ).slideIn(
                      RevealDirection.topStart,
                      distance: 16,
                      onVisible: true,
                    ),
              ),
              _modeToggle().slideIn(
                RevealDirection.topEnd,
                distance: 16,
                delay: const Duration(milliseconds: 60),
                onVisible: true,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 36.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _Range.values.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, i) {
                final r = _Range.values[i];
                final selected = r == _range;
                return Pressable(
                  scale: AppMotion.pressScaleSmall,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _range = r);
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      color: selected
                          ? AppColors.heroSurface
                          : AppColors.surfaceLight,
                      border: Border.all(
                        color: selected
                            ? AppColors.heroSurface
                            : AppColors.borderWarm,
                      ),
                    ),
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.goldLight
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    Widget seg(IconData icon, bool active, VoidCallback onTap) {
      return Pressable(
        scale: AppMotion.pressScaleSmall,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            color: active ? AppColors.heroSurface : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 18.sp,
            color: active ? AppColors.goldLight : AppColors.textMuted,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: [
          seg(
            Icons.grid_view_rounded,
            !_list,
            () => setState(() => _list = false),
          ),
          seg(
            Icons.view_agenda_outlined,
            _list,
            () => setState(() => _list = true),
          ),
        ],
      ),
    );
  }

  Widget _namesSliver(List<AsmaName> all) {
    final visible = all
        .where((n) => n.number >= _range.from && n.number <= _range.to)
        .toList();
    // Detail pager walks the currently visible set so swiping stays in range.
    void open(int i) => _openDetail(visible, i);

    if (_list) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        sliver: SliverList.separated(
          itemCount: visible.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, i) =>
              AsmaNameRow(name: visible[i], onTap: () => open(i)).slideInAt(i),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 0.92,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => AsmaNameTile(
            name: visible[i],
            onTap: () => open(i),
          ).slideInAt(i, columns: 3, distance: 16),
          childCount: visible.length,
        ),
      ),
    );
  }

  Widget _loadingSliver() {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 0.92,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, _) => ShimmerBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 20.r,
          ),
          childCount: 12,
        ),
      ),
    );
  }
}

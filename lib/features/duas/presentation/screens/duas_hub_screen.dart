import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../domain/entities/dua.dart';
import '../../domain/entities/dua_category.dart';
import '../../domain/entities/duas_bundle.dart';
import '../providers/dua_providers.dart';
import '../widgets/dua_common.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';

class DuasHubScreen extends ConsumerStatefulWidget {
  const DuasHubScreen({super.key});

  @override
  ConsumerState<DuasHubScreen> createState() => _DuasHubScreenState();
}

class _DuasHubScreenState extends ConsumerState<DuasHubScreen> {
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

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
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  /// A dua that suits the time of day, falling back to a daily pick.
  ({String label, List<Dua> pool, int index, String heading}) _suggest(
    DuasBundle b,
  ) {
    final now = DateTime.now();
    final h = now.hour;
    final (label, keys) = h >= 4 && h < 11
        ? ('For this morning', ['morning', 'dawn'])
        : h >= 15 && h < 20
        ? ('For this evening', ['evening', 'sunset'])
        : h >= 21 || h < 4
        ? ('Before you sleep', ['sleep', 'night', 'bed'])
        : ('Dua of the day', <String>[]);

    DuaCategory? cat;
    for (final c in b.categories) {
      final k = '${c.id} ${c.name}'.toLowerCase();
      if (keys.any(k.contains)) {
        cat = c;
        break;
      }
    }
    final pool = cat == null ? b.duas : b.byCategory(cat.id);
    final safe = pool.isEmpty ? b.duas : pool;
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return (
      label: label,
      pool: safe,
      index: safe.isEmpty ? 0 : dayOfYear % safe.length,
      heading: cat?.name ?? 'Duas',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundleAsync = ref.watch(duasBundleNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _hero()),
                ...bundleAsync.when(
                  data: _dataSlivers,
                  loading: _loadingSlivers,
                  error: (e, _) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(28.w),
                        child: Column(
                          children: [
                            Text(e.toString(), textAlign: TextAlign.center),
                            SizedBox(height: 12.h),
                            FilledButton(
                              onPressed: () =>
                                  ref.invalidate(duasBundleNotifierProvider),
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
              child: PinnedHeroBar(
                opacity: _bar,
                title: 'Duas',
                trailingIcon: Icons.search_rounded,
                trailingTooltip: 'Search duas',
                onTrailing: () => context.push('/duas/search'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    final seq = RevealSequence();
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 52,
            ),
          ),
          Positioned(
            right: -30.w,
            top: 30.h,
            child: Icon(
              Icons.nightlight_round,
              size: 190.sp,
              color: AppColors.gold.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + 70.h,
              24.w,
              26.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الدعاء',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: kDuaArabicFont,
                    fontSize: 46.sp,
                    color: AppColors.goldLight,
                    height: 1.4,
                  ),
                ).slideIn(RevealDirection.topStart, delay: seq.next()),
                Text(
                  'Duas & supplications',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
                SizedBox(height: 10.h),
                Text(
                  '“Call upon Me; I will respond to you.”  — Ghafir 40:60',
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                  ),
                ).slideIn(RevealDirection.end, delay: seq.next()),
                SizedBox(height: 20.h),
                Pressable(
                  onTap: () => context.push('/duas/search'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20.sp,
                          color: AppColors.goldLight,
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'Search by need, e.g. “anxiety”, “travel”',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 240),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _dataSlivers(DuasBundle bundle) {
    final s = bundle.duas.isEmpty ? null : _suggest(bundle);
    final saved = _savedDuas(bundle);

    return [
      if (s != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
            child: _suggestionCard(s),
          ),
        ),
      if (saved.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _sectionTitle('Your saved duas', Icons.favorite_rounded),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 132.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              scrollDirection: Axis.horizontal,
              itemCount: saved.length,
              separatorBuilder: (_, _) => SizedBox(width: 10.w),
              itemBuilder: (context, i) =>
                  _savedCard(saved, i).slideInAt(i, distance: 18),
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: _sectionTitle('Browse by moment', Icons.grid_view_rounded),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12.h,
            crossAxisSpacing: 12.w,
            childAspectRatio: 0.92,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _categoryCard(
              bundle.categories[i],
            ).slideInAt(i, columns: 2, distance: 18),
            childCount: bundle.categories.length,
          ),
        ),
      ),
    ];
  }

  List<Dua> _savedDuas(DuasBundle bundle) {
    final favs = ref.watch(favoritesNotifierProvider).valueOrNull ?? [];
    final ids = favs
        .where((f) => f.type == FavoriteContentType.dua)
        .map((f) => f.referenceId)
        .toSet();
    return bundle.duas.where((d) => ids.contains('${d.id}')).toList();
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 26.h, 20.w, 12.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppColors.gold),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ),
        ],
      ),
    ).slideIn(RevealDirection.topStart, distance: 16, onVisible: true);
  }

  Widget _suggestionCard(
    ({String label, List<Dua> pool, int index, String heading}) s,
  ) {
    final d = s.pool[s.index];
    return Pressable(
      onTap: () => openDuaReader(context, s.pool, s.index, heading: s.heading),
      child: Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(26.r),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    s.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.sp,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ).slideIn(
                  RevealDirection.topStart,
                  distance: 16,
                  onVisible: true,
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18.sp,
                  color: AppColors.gold,
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              d.arabic,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: kDuaArabicFont,
                fontSize: 24.sp,
                height: 1.9,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              d.title,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ).slideIn(
              RevealDirection.bottomStart,
              delay: const Duration(milliseconds: 260),
              onVisible: true,
            ),
            SizedBox(height: 4.h),
            Text(
              d.translation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 320),
              onVisible: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedCard(List<Dua> saved, int i) {
    final d = saved[i];
    return Pressable(
      onTap: () => openDuaReader(context, saved, i, heading: 'Saved duas'),
      child: Container(
        width: 210.w,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.duasAccentBg,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: AppColors.duasAccent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ),
            const Spacer(),
            Text(
              d.arabic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: kDuaArabicFont,
                fontSize: 20.sp,
                color: AppColors.duasAccent,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(DuaCategory c) {
    final st = DuaCategoryStyle.of(c);
    return PressScale(
      child: Material(
        color: st.bg,
        borderRadius: BorderRadius.circular(24.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/duas/category/${c.id}', extra: c);
          },
          splashColor: st.accent.withValues(alpha: 0.12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: st.accent.withValues(alpha: 0.2)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GeometricPattern(
                    color: st.accent.withValues(alpha: 0.07),
                    cell: 34,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42.w,
                            height: 42.w,
                            decoration: BoxDecoration(
                              color: st.accent,
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Icon(
                              st.icon,
                              size: 22.sp,
                              color: AppColors.surfaceLight,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: st.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              '${c.count}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: st.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        c.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _loadingSlivers() {
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
        sliver: SliverToBoxAdapter(
          child: ShimmerBox(
            width: double.infinity,
            height: 190.h,
            borderRadius: 26.r,
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20.w, 26.h, 20.w, 0),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12.h,
            crossAxisSpacing: 12.w,
            childAspectRatio: 0.92,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, _) => ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 24.r,
            ),
            childCount: 6,
          ),
        ),
      ),
    ];
  }
}

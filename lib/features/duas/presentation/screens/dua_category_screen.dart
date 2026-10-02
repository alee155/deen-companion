import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../domain/entities/dua_category.dart';
import '../providers/dua_providers.dart';
import '../widgets/dua_common.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';

class DuaCategoryScreen extends ConsumerStatefulWidget {
  final DuaCategory category;
  const DuaCategoryScreen({super.key, required this.category});

  @override
  ConsumerState<DuaCategoryScreen> createState() => _DuaCategoryScreenState();
}

class _DuaCategoryScreenState extends ConsumerState<DuaCategoryScreen> {
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 120 : 0.0).clamp(
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

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final st = DuaCategoryStyle.of(category);
    // Filters the already-cached bundle — no network call happens here.
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
                SliverToBoxAdapter(child: _hero(category, st)),
                bundleAsync.when(
                  data: (bundle) {
                    final duas = bundle.byCategory(category.id);
                    if (duas.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40.w),
                          child: Center(
                            child: Text(
                              'No duas here yet.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ).slideIn(RevealDirection.bottom),
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                      sliver: SliverList.separated(
                        itemCount: duas.length,
                        separatorBuilder: (_, _) => SizedBox(height: 12.h),
                        itemBuilder: (context, i) => DuaPreviewCard(
                          dua: duas[i],
                          number: i + 1,
                          accent: st.accent,
                          bg: st.bg,
                          onTap: () => openDuaReader(
                            context,
                            duas,
                            i,
                            heading: category.name,
                          ),
                        ).slideInAt(i),
                      ),
                    );
                  },
                  loading: () => SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40.w),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(28.w),
                      child: Text(e.toString(), textAlign: TextAlign.center),
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
              child: PinnedHeroBar(
                opacity: _bar,
                title: category.name,
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

  Widget _hero(DuaCategory c, DuaCategoryStyle st) {
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 48,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + 66.h,
              24.w,
              26.h,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 84.w,
                  height: 84.w,
                  child: CustomPaint(
                    painter: StarPainter(
                      fill: AppColors.gold.withValues(alpha: 0.16),
                      stroke: AppColors.goldLight,
                      strokeWidth: 1.4,
                      inner: 0.76,
                    ),
                    child: Icon(
                      st.icon,
                      size: 34.sp,
                      color: AppColors.goldLight,
                    ),
                  ),
                ).slideIn(RevealDirection.topStart, distance: 18),
                SizedBox(width: 18.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ).slideIn(RevealDirection.top, delay: seq.next()),
                      SizedBox(height: 6.h),
                      Text(
                        c.description,
                        style: TextStyle(
                          fontSize: 13.sp,
                          height: 1.45,
                          color: AppColors.onHeroSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${c.count} duas',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldLight,
                          ),
                        ),
                      ).slideIn(RevealDirection.bottomEnd, delay: seq.next()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

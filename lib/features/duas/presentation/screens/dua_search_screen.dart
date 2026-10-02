import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/entities/dua.dart';
import '../../domain/entities/duas_bundle.dart';
import '../providers/dua_providers.dart';
import '../widgets/dua_common.dart';

class DuaSearchScreen extends ConsumerStatefulWidget {
  const DuaSearchScreen({super.key});

  @override
  ConsumerState<DuaSearchScreen> createState() => _DuaSearchScreenState();
}

class _DuaSearchScreenState extends ConsumerState<DuaSearchScreen> {
  final _controller = TextEditingController();
  String? _activeCategoryFilter;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    setState(() => _activeCategoryFilter = null);
    ref.read(duaSearchNotifierProvider.notifier).search(query);
  }

  void _pickCategory(String id, String name) {
    _controller.text = name;
    FocusScope.of(context).unfocus();
    setState(() => _activeCategoryFilter = id);
  }

  void _clear() {
    _controller.clear();
    setState(() => _activeCategoryFilter = null);
    ref.read(duaSearchNotifierProvider.notifier).search('');
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(duaSearchNotifierProvider);
    final bundleAsync = ref.watch(duasBundleNotifierProvider);
    final idle =
        _activeCategoryFilter == null &&
        searchState.value == null &&
        !searchState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ContentSwitcher(
                child: idle
                    ? _idle(bundleAsync.valueOrNull)
                    : _results(bundleAsync.valueOrNull, searchState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 18.h),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18.r),
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
                      SizedBox(width: 8.w),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                          ),
                          cursorColor: AppColors.gold,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search duas…',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                          onSubmitted: _runSearch,
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        Pressable(
                          scale: AppMotion.pressScaleSmall,
                          onTap: _clear,
                          child: Icon(
                            Icons.close_rounded,
                            size: 18.sp,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _idle(DuasBundle? bundle) {
    return ListView(
      key: const ValueKey('idle'),
      padding: EdgeInsets.all(20.w),
      children: [
        Text(
          'Browse by category',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ).slideIn(RevealDirection.topStart, distance: 16),
        SizedBox(height: 4.h),
        Text(
          'Or type what you’re feeling or need and press search.',
          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
        ).slideIn(
          RevealDirection.bottomEnd,
          delay: const Duration(milliseconds: 60),
        ),
        SizedBox(height: 14.h),
        if (bundle != null)
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final (ci, c) in bundle.categories.indexed)
                Builder(
                  builder: (_) {
                    final st = DuaCategoryStyle.of(c);
                    return Pressable(
                      scale: AppMotion.pressScaleSmall,
                      onTap: () => _pickCategory(c.id, c.name),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: st.bg,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(st.icon, size: 15.sp, color: st.accent),
                            SizedBox(width: 6.w),
                            Text(
                              c.name,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: st.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).slideInAt(ci, columns: 3, distance: 18);
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _list(List<Dua> duas, DuasBundle? bundle, String heading) {
    if (duas.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40.sp,
              color: AppColors.textMuted,
            ).slideIn(RevealDirection.top, distance: 16),
            SizedBox(height: 10.h),
            Text(
              'No duas found.',
              style: TextStyle(color: AppColors.textSecondary),
            ).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 60),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      key: ValueKey('list$heading${duas.length}'),
      padding: EdgeInsets.all(20.w),
      itemCount: duas.length + 1,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (context, i) {
        if (i == duas.length) {
          return const BannerAdWidget(
            margin: EdgeInsets.symmetric(vertical: 4),
          );
        }
        final d = duas[i];
        DuaCategoryStyle st;
        try {
          st = DuaCategoryStyle.of(
            bundle!.categories.firstWhere((c) => c.id == d.category),
          );
        } catch (_) {
          st = DuaCategoryStyle(
            Icons.auto_awesome_rounded,
            AppColors.duasAccent,
            AppColors.duasAccentBg,
          );
        }
        return DuaPreviewCard(
          dua: d,
          number: i + 1,
          accent: st.accent,
          bg: st.bg,
          onTap: () => openDuaReader(context, duas, i, heading: heading),
        ).slideInAt(i);
      },
    );
  }

  Widget _results(DuasBundle? bundle, AsyncValue<List<Dua>?> searchState) {
    if (_activeCategoryFilter != null) {
      if (bundle == null) {
        return Center(child: CircularProgressIndicator(color: AppColors.gold));
      }
      return _list(
        bundle.byCategory(_activeCategoryFilter!),
        bundle,
        _controller.text,
      );
    }
    return searchState.when(
      data: (results) => _list(results ?? const [], bundle, 'Search results'),
      loading: () =>
          Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

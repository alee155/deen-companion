import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/hadith_providers.dart';

class HadithReadingScreen extends ConsumerStatefulWidget {
  final String collectionKey;
  const HadithReadingScreen({super.key, required this.collectionKey});

  @override
  ConsumerState<HadithReadingScreen> createState() =>
      _HadithReadingScreenState();
}

class _HadithReadingScreenState extends ConsumerState<HadithReadingScreen> {
  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
      _maybeLoadMore();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    final state = ref
        .read(hadithListNotifierProvider(widget.collectionKey))
        .value;
    if (state == null) return;
    if (_page >= state.hadiths.length - 3 &&
        state.hasMore &&
        !state.isLoadingMore) {
      ref
          .read(hadithListNotifierProvider(widget.collectionKey).notifier)
          .loadMore(widget.collectionKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(
      hadithListNotifierProvider(widget.collectionKey),
    );

    return Scaffold(
      backgroundColor: AppColors.emeraldInkDark,
      body: SafeArea(
        child: listState.when(
          data: (state) {
            if (state.hadiths.isEmpty)
              return const Center(
                child: Text(
                  'No hadiths found.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Text(
                        '${_page.round() + 1} of ${state.hadiths.length}${state.hasMore ? '+' : ''}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      SizedBox(width: 48.w),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: state.hadiths.length,
                    itemBuilder: (context, index) {
                      final delta = index - _page;
                      final t = delta.clamp(-1.0, 1.0);
                      final angle = t * 1.3; // radians of curl
                      final shadowOpacity = (t.abs() * 0.5).clamp(0.0, 0.5);

                      return Transform(
                        alignment: t <= 0
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(angle),
                        child: Stack(
                          children: [
                            _pageContent(
                              state.hadiths[index].arabic,
                              state.hadiths[index].english,
                              state.hadiths[index].hadithNumber,
                              state.hadiths[index].grade,
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  color: Colors.black.withOpacity(
                                    shadowOpacity,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ), // TODO: swap for shimmer per item 2
          error: (error, _) => Center(
            child: Text(
              error.toString(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageContent(String arabic, String english, int number, String grade) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFBF6EC,
        ), // aged-paper tone, distinct from app parchment
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.hadithAccentBg,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '№ $number',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.hadithAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  grade,
                  style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 19.sp,
                height: 2.0,
                color: const Color(0xFF2B2420),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              english,
              style: TextStyle(
                fontSize: 15.sp,
                height: 1.7,
                color: const Color(0xFF2B2420),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

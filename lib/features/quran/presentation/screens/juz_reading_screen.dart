import 'package:deen_companion/features/quran/presentation/screens/juz_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../../../shared/widgets/deen_app_bar.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../../../shared/widgets/reader_settings_sheet.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/juz.dart';
import '../../domain/juz_arabic_names.dart';
import '../providers/quran_providers.dart';
import '../widgets/juz_verse_tile.dart';

/// The Juz reader.
///
/// A fixed banner — the Juz's name and its verse count over a mosque
/// illustration — sits above the reading area while the verses themselves
/// scroll underneath it, the way a section header stays put while its list
/// moves. Chrome besides that is unchanged from before: reading settings,
/// favoriting, a scroll progress indicator, and switching to another Juz
/// without a trip back to the hub.
class JuzReadingScreen extends ConsumerStatefulWidget {
  final int juzNumber;
  const JuzReadingScreen({super.key, required this.juzNumber});

  @override
  ConsumerState<JuzReadingScreen> createState() => _JuzReadingScreenState();
}

class _JuzReadingScreenState extends ConsumerState<JuzReadingScreen> {
  final ScrollController _controller = ScrollController();
  double _progress = 0;
  bool _loggedActivity = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final max = _controller.position.maxScrollExtent;
    final next = max <= 0 ? 1.0 : (_controller.offset / max).clamp(0.0, 1.0);
    if ((next - _progress).abs() > 0.005) setState(() => _progress = next);
  }

  void _logActivityOnce(Juz juz) {
    if (_loggedActivity) return;
    _loggedActivity = true;
    final first = juz.verses.isEmpty ? null : juz.verses.first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(recentActivityNotifierProvider.notifier)
          .logActivity(
            RecentActivityItem(
              id: RecentActivityItem.buildId(
                RecentActivityType.juz,
                '${widget.juzNumber}',
              ),
              type: RecentActivityType.juz,
              referenceId: '${widget.juzNumber}',
              title: 'Juz ${widget.juzNumber}',
              subtitle: first == null ? null : 'Starts at ${first.surahName}',
              route: '/juz/${widget.juzNumber}',
              viewedAt: DateTime.now(),
            ),
          );
    });
  }

  FavoriteItem _favoriteFor(Juz juz) {
    final first = juz.verses.isEmpty ? null : juz.verses.first;
    return FavoriteItem(
      id: FavoriteItem.buildId(FavoriteContentType.juz, '${widget.juzNumber}'),
      type: FavoriteContentType.juz,
      referenceId: '${widget.juzNumber}',
      title: 'Juz ${widget.juzNumber}',
      subtitle: first == null ? null : 'Starts at ${first.surahName}',
      route: '/juz/${widget.juzNumber}',
      savedAt: DateTime.now(),
    );
  }

  Future<void> _switchJuz() async {
    final chosen = await showJuzPickerSheet(
      context,
      selected: widget.juzNumber,
    );
    if (chosen == null || chosen == widget.juzNumber || !mounted) return;
    // Replaces rather than stacks, so Back still returns to the hub instead
    // of walking through every Juz that was opened.
    context.pushReplacement('/juz/$chosen');
  }

  @override
  Widget build(BuildContext context) {
    final juzAsync = ref.watch(juzNotifierProvider(widget.juzNumber));
    final preferences = ref.watch(readingPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: DeenAppBar(
        title: 'Juz ${widget.juzNumber}',
        subtitle: juzAsync.value?.verses.isNotEmpty == true
            ? juzAsync.value!.verses.first.surahName
            : null,
        actions: [
          if (juzAsync.value != null)
            FavoriteButton(item: _favoriteFor(juzAsync.value!)),
          IconButton(
            tooltip: 'Reading settings',
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: () => showReaderSettingsSheet(context),
          ),
          IconButton(
            tooltip: 'Switch Juz',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: _switchJuz,
          ),
        ],
      ),
      body: juzAsync.when(
        data: (juz) {
          if (juz.verses.isEmpty) return const _EmptyState();
          _logActivityOnce(juz);

          return Column(
            children: [
              _ReadingProgress(progress: _progress),
              _JuzHeaderBanner(
                juzNumber: widget.juzNumber,
                totalVerses: juz.totalVerses,
              ),
              Expanded(
                child: ListView.builder(
                  controller: _controller,
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
                  itemCount: juz.verses.length,
                  itemBuilder: (context, index) {
                    final verse = juz.verses[index];
                    final isSurahStart =
                        index == 0 ||
                        juz.verses[index - 1].surahName != verse.surahName;

                    return Padding(
                      padding: EdgeInsets.only(bottom: 14.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          JuzVerseTile(
                            verse: verse,
                            preferences: preferences,
                            showSurahBanner: isSurahStart,
                          ),
                          if (index != juz.verses.length - 1)
                            Padding(
                              padding: EdgeInsets.only(top: 14.h),
                              child: OrnamentDivider(ruleWidth: 24.w),
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
        loading: () => const _ReaderSkeleton(),
        error: (error, _) => Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: FailureView(
              failure: failureFrom(error),
              onRetry: () async =>
                  ref.invalidate(juzNotifierProvider(widget.juzNumber)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The fixed banner above the verse list — a mosque illustration with a
/// black wash for legibility, the Juz's Arabic name at the top-left and its
/// verse count at the top-right. Stays put while the list scrolls beneath
/// it, the way a printed Mushaf's running header never moves even as your
/// eye travels down the page.
class _JuzHeaderBanner extends StatelessWidget {
  final int juzNumber;
  final int totalVerses;

  const _JuzHeaderBanner({required this.juzNumber, required this.totalVerses});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 108.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/juzz_card.png', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.30),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14.h,
            left: 16.w,
            right: 16.w,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'JUZ $juzNumber',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        juzArabicName(juzNumber),
                        textDirection: TextDirection.rtl,
                        style: AppTypography.arabicBody.copyWith(
                          fontSize: 26.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '$totalVerses Verses',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Hairline progress rule tracking scroll position through the Juz.
class _ReadingProgress extends StatelessWidget {
  final double progress;
  const _ReadingProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3.h,
      color: AppColors.borderWarm,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: AppMotion.fast,
        curve: AppMotion.entrance,
        builder: (context, value, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: Container(color: AppColors.emeraldInk),
        ),
      ),
    );
  }
}

class _ReaderSkeleton extends StatelessWidget {
  const _ReaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
      itemCount: 5,
      separatorBuilder: (_, __) => SizedBox(height: 18.h),
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerBox(width: 26.w, height: 26.w, borderRadius: 8.r),
                SizedBox(width: 8.w),
                ShimmerBox(width: 90.w, height: 12.h, borderRadius: 4.r),
              ],
            ),
            SizedBox(height: 10.h),
            ShimmerBox(width: double.infinity, height: 16.h, borderRadius: 4.r),
            SizedBox(height: 8.h),
            ShimmerBox(width: 220.w, height: 14.h, borderRadius: 4.r),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 36.sp,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 12.h),
            Text(
              'Nothing to read here yet',
              style: AppTypography.headline.copyWith(
                fontSize: 16.sp,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'This Juz returned no verses. Try again in a moment.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

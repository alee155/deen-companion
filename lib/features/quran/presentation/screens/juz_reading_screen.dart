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
import '../../../../shared/widgets/reader_settings_sheet.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/juz.dart';
import '../providers/quran_providers.dart';
import '../widgets/juz_verse_tile.dart';

/// The Juz reader.
///
/// A continuous scroll through the Juz's verses — right for ~200 verses of
/// Quran text, where paging one verse at a time (à la Hadith) would turn a
/// single Juz into 200 swipes. What it borrows from the Hadith reader is the
/// supporting toolbar: reading settings, favoriting, a progress indicator,
/// and switching to another Juz without a trip back to the hub.
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
              Expanded(
                child: ListView.builder(
                  controller: _controller,
                  itemCount: juz.verses.length,
                  itemBuilder: (context, index) {
                    final verse = juz.verses[index];
                    final isNewSurah =
                        index == 0 ||
                        juz.verses[index - 1].surahName != verse.surahName;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isNewSurah) _SurahHeader(name: verse.surahName),
                        JuzVerseTile(verse: verse, preferences: preferences),
                        Divider(height: 1, color: AppColors.borderWarm),
                      ],
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

/// Marks where a new surah begins within the Juz — a Juz usually spans parts
/// of two to four surahs, and without this the verses would read as one
/// undifferentiated block.
class _SurahHeader extends StatelessWidget {
  final String name;
  const _SurahHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.quranAccentBg.withValues(alpha: 0.5),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 14.sp,
            color: AppColors.quranAccent,
          ),
          SizedBox(width: 6.w),
          Text(
            name,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.quranAccent,
              fontWeight: FontWeight.w700,
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
          child: Container(color: AppColors.quranAccent),
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

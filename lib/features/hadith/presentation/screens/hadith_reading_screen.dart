import 'package:deen_companion/shared/providers/reading_preferences_provider.dart';
import 'package:deen_companion/shared/widgets/reader_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/deen_app_bar.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../providers/hadith_providers.dart';

import '../widgets/hadith_collection_picker_sheet.dart';
import '../widgets/hadith_reader_page.dart';

/// The hadith reader.
///
/// One horizontally-paged view of hadiths, with chrome (header, progress rule,
/// controls) that can step out of the way entirely: tapping the page toggles
/// focus mode, and a second tap brings everything back.
class HadithReadingScreen extends ConsumerStatefulWidget {
  final String collectionKey;
  const HadithReadingScreen({super.key, required this.collectionKey});

  @override
  ConsumerState<HadithReadingScreen> createState() =>
      _HadithReadingScreenState();
}

class _HadithReadingScreenState extends ConsumerState<HadithReadingScreen> {
  late final PageController _controller;
  int _page = 0;
  bool _focusMode = false;
  bool _loggedActivity = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, HadithListState state) {
    // Fires once per settled page, not per scroll frame.
    setState(() => _page = index);

    if (index >= state.hadiths.length - 3 &&
        state.hasMore &&
        !state.isLoadingMore) {
      ref
          .read(hadithListNotifierProvider(widget.collectionKey).notifier)
          .loadMore(widget.collectionKey);
    }
  }

  void _toggleFocusMode() {
    setState(() => _focusMode = !_focusMode);
    HapticFeedback.selectionClick();
  }

  Future<void> _animateTo(int index) {
    return _controller.animateToPage(
      index,
      duration: AppMotion.normal,
      curve: AppMotion.entrance,
    );
  }

  /// Logged once per visit, so Recent activity shows the book being read
  /// rather than one entry per page turn.
  void _logActivityOnce(Hadith hadith, HadithCollection? collection) {
    if (_loggedActivity) return;
    _loggedActivity = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(recentActivityNotifierProvider.notifier)
          .logActivity(
            RecentActivityItem(
              id: RecentActivityItem.buildId(
                RecentActivityType.hadith,
                widget.collectionKey,
              ),
              type: RecentActivityType.hadith,
              referenceId: widget.collectionKey,
              title: collection?.name ?? hadith.collectionName,
              subtitle: 'Reading · Hadith ${hadith.hadithNumber}',
              route: '/hadith/read/${widget.collectionKey}',
              viewedAt: DateTime.now(),
            ),
          );
    });
  }

  Future<void> _copy(Hadith hadith) async {
    await Clipboard.setData(ClipboardData(text: hadith.toShareText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hadith copied, with its reference')),
    );
  }

  Future<void> _share(Hadith hadith) =>
      Share.share(hadith.toShareText(), subject: hadith.collectionName);

  /// Switch books without going back to the library first.
  Future<void> _switchCollection() async {
    final collections = ref.read(hadithCollectionsNotifierProvider).value;
    if (collections == null || collections.isEmpty) return;

    final key = await showHadithCollectionPicker(
      context,
      collections: collections,
      selectedKey: widget.collectionKey,
    );
    if (key == null || key == widget.collectionKey || !mounted) return;
    // Replaces rather than stacks, so Back still returns to the library
    // instead of walking through every book that was opened.
    context.pushReplacement('/hadith/read/$key');
  }

  FavoriteItem _favoriteFor(Hadith hadith) => FavoriteItem(
    id: FavoriteItem.buildId(FavoriteContentType.hadith, hadith.id),
    type: FavoriteContentType.hadith,
    referenceId: hadith.id,
    title: '${hadith.collectionName} · Hadith ${hadith.hadithNumber}',
    subtitle: hadith.english,
    route: '/hadith/read/${hadith.collection}',
    savedAt: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(
      hadithListNotifierProvider(widget.collectionKey),
    );
    final preferences = ref.watch(readingPreferencesProvider);
    final collection = ref.watch(
      hadithCollectionByKeyProvider(widget.collectionKey),
    );

    final hadiths = listState.value?.hadiths ?? const <Hadith>[];
    final currentHadith = _page < hadiths.length ? hadiths[_page] : null;
    if (currentHadith != null) _logActivityOnce(currentHadith, collection);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: _focusMode
          ? null
          : DeenAppBar(
              title: collection?.name ?? 'Hadith',
              subtitle: currentHadith == null
                  ? collection?.arabicName
                  : 'Hadith ${currentHadith.hadithNumber}',
              actions: [
                if (currentHadith != null)
                  FavoriteButton(size: 20, item: _favoriteFor(currentHadith)),
                IconButton(
                  tooltip: 'Reading settings',
                  icon: const Icon(Icons.text_fields_rounded),
                  onPressed: () => showReaderSettingsSheet(context),
                ),
                if (currentHadith != null)
                  _MoreMenu(
                    onCopy: () => _copy(currentHadith),
                    onShare: () => _share(currentHadith),
                    onFocus: _toggleFocusMode,
                    onSwitchBook: _switchCollection,
                  ),
              ],
            ),
      body: listState.when(
        data: (state) {
          if (state.hadiths.isEmpty) return const _EmptyState();

          return SafeArea(
            // In focus mode the header is gone, so the page has to keep clear
            // of the status bar itself.
            top: _focusMode,
            child: Column(
              children: [
                _ReadingProgress(
                  visible: !_focusMode,
                  progress: (_page + 1) / state.hadiths.length,
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: state.hadiths.length,
                    onPageChanged: (index) => _onPageChanged(index, state),
                    itemBuilder: (context, index) {
                      final hadith = state.hadiths[index];
                      return HadithReaderPage(
                        // Keyed by hadith so the entrance animation replays
                        // for a genuinely new page and not on every parent
                        // rebuild — otherwise dragging the size slider would
                        // re-fade the text under your finger.
                        key: ValueKey(hadith.id),
                        hadith: hadith,
                        collection: collection,
                        preferences: preferences,
                        position: index + 1,
                        total: state.hadiths.length,
                        hasMore: state.hasMore,
                        onTapBody: _toggleFocusMode,
                      ).appear();
                    },
                  ),
                ),
                _ReaderControls(
                  visible: !_focusMode,
                  page: _page,
                  count: state.hadiths.length,
                  isLoadingMore: state.isLoadingMore,
                  onPrevious: _page > 0 ? () => _animateTo(_page - 1) : null,
                  onNext: _page < state.hadiths.length - 1
                      ? () => _animateTo(_page + 1)
                      : null,
                ),
              ],
            ),
          );
        },
        loading: () => const _ReaderSkeleton(),
        error: (error, _) => Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: FailureView(
              failure: failureFrom(error),
              onRetry: () async => ref.invalidate(
                hadithListNotifierProvider(widget.collectionKey),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onFocus;
  final VoidCallback onSwitchBook;

  const _MoreMenu({
    required this.onCopy,
    required this.onShare,
    required this.onFocus,
    required this.onSwitchBook,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded),
      color: AppColors.surfaceLight,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: onCopy,
          child: const _MenuRow(icon: Icons.copy_rounded, label: 'Copy hadith'),
        ),
        PopupMenuItem(
          value: onShare,
          child: const _MenuRow(
            icon: Icons.ios_share_rounded,
            label: 'Share hadith',
          ),
        ),
        PopupMenuItem(
          value: onFocus,
          child: const _MenuRow(
            icon: Icons.fullscreen_rounded,
            label: 'Focus mode',
          ),
        ),
        PopupMenuItem(
          value: onSwitchBook,
          child: const _MenuRow(
            icon: Icons.swap_horiz_rounded,
            label: 'Switch book',
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.inkText),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: AppColors.inkText)),
      ],
    );
  }
}

/// Hairline progress rule. Glides as pages turn instead of jumping, and
/// collapses to nothing in focus mode.
class _ReadingProgress extends StatelessWidget {
  final bool visible;
  final double progress;

  const _ReadingProgress({required this.visible, required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.entrance,
      height: visible ? 3.h : 0,
      color: AppColors.borderWarm,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: AppMotion.fast,
        curve: AppMotion.entrance,
        builder: (context, value, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: Container(color: AppColors.hadithAccent),
        ),
      ),
    );
  }
}

/// Prev / position / next. Generous targets, and it says when the next batch
/// of hadiths is still loading rather than looking stuck.
class _ReaderControls extends StatelessWidget {
  final bool visible;
  final int page;
  final int count;
  final bool isLoadingMore;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _ReaderControls({
    required this.visible,
    required this.page,
    required this.count,
    required this.isLoadingMore,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.entrance,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                border: Border(top: BorderSide(color: AppColors.borderWarm)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Previous hadith',
                    onPressed: onPrevious,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${page + 1} / $count',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.inkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        isLoadingMore ? 'Loading more…' : 'Swipe to continue',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  _NavButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Next hadith',
                    onPressed: onNext,
                  ),
                ],
              ),
            ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _NavButton({required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 26.sp,
      // Comfortably past the 44dp minimum touch target.
      constraints: BoxConstraints(minWidth: 52.w, minHeight: 48.h),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.inkText,
        disabledForegroundColor: AppColors.borderWarm,
      ),
      icon: Icon(icon),
    );
  }
}

class _ReaderSkeleton extends StatelessWidget {
  const _ReaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 42.w, height: 42.w, borderRadius: 12.r),
              SizedBox(width: 12.w),
              ShimmerBox(width: 120.w, height: 16.h, borderRadius: 4.r),
              const Spacer(),
              ShimmerBox(width: 70.w, height: 22.h, borderRadius: 20.r),
            ],
          ),
          SizedBox(height: 22.h),
          ShimmerBox(width: double.infinity, height: 170.h, borderRadius: 18.r),
          SizedBox(height: 24.h),
          ShimmerBox(width: 100.w, height: 12.h, borderRadius: 4.r),
          SizedBox(height: 14.h),
          ShimmerBox(width: double.infinity, height: 14.h, borderRadius: 4.r),
          SizedBox(height: 10.h),
          ShimmerBox(width: double.infinity, height: 14.h, borderRadius: 4.r),
          SizedBox(height: 10.h),
          ShimmerBox(width: 220.w, height: 14.h, borderRadius: 4.r),
        ],
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
              'This collection returned no hadiths. Try another book, or open '
              'it again in a moment.',
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

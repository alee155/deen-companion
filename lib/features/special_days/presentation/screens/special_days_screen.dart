import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/domain/explore_icon_assets.dart';
import '../../../groups/presentation/widgets/group_form_widgets.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../../../prayer_logs/presentation/prayer_labels.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/special_days.dart';
import '../../domain/special_days_failure.dart';
import '../../domain/special_days_calendar.dart';
import '../providers/special_days_providers.dart';
import '../widgets/special_days_calendar_card.dart';
import '../special_days_labels.dart';

/// Special days: for the days prayer is exempt (up to ten), five different
/// photos are uploaded first, then one switch starts the period. While it runs
/// the server logs every prayer on her behalf, so streaks and scores carry on;
/// it ends when she turns it off, or by itself after ten days.
class SpecialDaysScreen extends ConsumerStatefulWidget {
  const SpecialDaysScreen({super.key});

  @override
  ConsumerState<SpecialDaysScreen> createState() => _SpecialDaysScreenState();
}

class _SpecialDaysScreenState extends ConsumerState<SpecialDaysScreen> {
  final _picker = ImagePicker();
  final _photosKey = GlobalKey();
  // The hero stays put: the bar over it never changes.
  final _bar = ValueNotifier<double>(0);

  /// The prayer whose photo is being sent or removed.
  PrayerName? _busyPrayer;
  bool _toggling = false;

  /// After a refused start, the missing photos are drawn attention to.
  bool _highlightMissing = false;

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  void _toast(String message) => showAppToast(context, message);

  Future<void> _pick(PrayerName prayer) async {
    // Choose, look at it, and only then send it: "Choose another" goes round
    // again.
    String? path;
    while (path == null) {
      final source = await showImageSourceSheet(
        context,
        title: '${prayer.label} photo',
      );
      if (source == null) return;
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null || !mounted) return;
      final choice = await showPhotoPreview(
        context,
        prayer: prayer,
        path: image.path,
      );
      if (!mounted || choice == null) return;
      if (choice == PhotoChoice.use) path = image.path;
    }

    setState(() => _busyPrayer = prayer);
    final failure = await ref
        .read(specialDaysProvider.notifier)
        .uploadImage(prayer, path);
    if (!mounted) return;
    setState(() => _busyPrayer = null);
    if (failure != null) {
      _toast(specialDaysMessage(failure, state: _state));
      return;
    }
    ref
        .read(specialDaysPreviewsProvider.notifier)
        .update((m) => {...m, prayer: path!});
    if (_state?.hasAllImages ?? false) {
      setState(() => _highlightMissing = false);
    }
    if (_state?.active ?? false) {
      _toast('Photo updated. ${prayer.label} will use it from its next time.');
    }
  }

  Future<void> _remove(PrayerName prayer) async {
    // While special days run, no photo means that prayer is not logged for her
    // until she adds one again: say so before it happens.
    if (_state?.active ?? false) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove the ${prayer.label} photo?'),
          content: Text(
            'While special days are on, ${prayer.label} won’t be logged for '
            'you until you add a photo for it again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    setState(() => _busyPrayer = prayer);
    final failure = await ref
        .read(specialDaysProvider.notifier)
        .removeImage(prayer);
    if (!mounted) return;
    setState(() => _busyPrayer = null);
    if (failure != null) {
      _toast(specialDaysMessage(failure, state: _state));
      return;
    }
    ref.read(specialDaysPreviewsProvider.notifier).update((m) {
      final next = {...m}..remove(prayer);
      return next;
    });
  }

  SpecialDays? get _state => ref.read(specialDaysProvider).valueOrNull;

  Future<void> _start() async {
    final state = _state;
    if (state == null || _toggling) return;
    HapticFeedback.selectionClick();

    // Don't ask the server what we already know it will refuse.
    if (!state.hasAllImages) {
      _showMissing(state.infoMessage);
      return;
    }
    setState(() => _toggling = true);
    final failure = await ref
        .read(specialDaysProvider.notifier)
        .setActive(true);
    if (!mounted) return;
    setState(() => _toggling = false);
    if (failure == null) {
      final ends = shortLocalDate(_state?.endsLocalDate);
      _toast(
        ends == null
            ? 'Special days have started.'
            : 'Special days have started. They end on $ends.',
      );
      return;
    }
    if (failure is SpecialDaysFailure &&
        failure.code == SpecialDaysErrorCode.imagesRequired) {
      _showMissing(failure.message);
      return;
    }
    _toast(specialDaysMessage(failure, state: _state));
  }

  /// The server wants more photos: say so, and take her to the empty ones.
  void _showMissing(String? message) {
    setState(() => _highlightMissing = true);
    _toast(
      message ?? 'Please upload 5 different photos first, one for each prayer.',
    );
    final ctx = _photosKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _end() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End special days?'),
        content: const Text(
          'We’ll stop logging your prayers for you. Your usual streak and '
          'scoring rules apply again from now. Prayers already logged stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep on'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _toggling = true);
    final failure = await ref
        .read(specialDaysProvider.notifier)
        .setActive(false);
    if (!mounted) return;
    setState(() => _toggling = false);
    _toast(
      failure == null
          ? 'Special days ended. Your usual streak and scoring apply again.'
          : specialDaysMessage(failure, state: _state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(specialDaysProvider);
    final state = async.valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            Column(
              children: [
                // Fixed: it doesn't scroll away or animate when things change.
                _hero(state),
                Expanded(
                  child: CustomScrollView(
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      ..._body(async),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 32.h,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(opacity: _bar, title: 'Special days'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(SpecialDays? state) {
    // The server's end date is the first day after the period, so the chip
    // names the last day she is covered, which is what the calendar shows.
    final calendar = state == null ? null : SpecialDaysCalendar.of(state);
    final until = calendar == null ? null : shortDate(calendar.days.last.date);
    return FeatureHero(
      animate: false,
      title: 'Special days',
      subtitle: 'Keep your streak going on the days prayer is exempt.',
      ghostIcon: Icons.favorite_rounded,
      chips: [
        if (state != null && state.active) ...[
          FeatureHeroChip(
            Icons.hourglass_bottom_rounded,
            daysLeftText(state.daysRemaining),
          ),
          if (until != null)
            FeatureHeroChip(Icons.event_rounded, 'Until $until'),
        ] else if (state != null && state.eligible) ...[
          FeatureHeroChip(
            Icons.photo_library_rounded,
            '${state.imageCount} of 5 photos',
          ),
          const FeatureHeroChip(Icons.date_range_rounded, 'Up to 10 days'),
        ] else
          const FeatureHeroChip(Icons.favorite_border_rounded, 'For sisters'),
      ],
    );
  }

  List<Widget> _body(AsyncValue<SpecialDays> async) {
    final previews = ref.watch(specialDaysPreviewsProvider);
    final imagesAsync = ref.watch(specialDayImagesProvider);
    final images = imagesAsync.valueOrNull ?? const {};
    final imagesLoading = imagesAsync.isLoading;
    EdgeInsets pad([double top = 0]) => EdgeInsets.fromLTRB(20.w, top, 20.w, 0);

    return async.when(
      loading: () => [
        SliverPadding(
          padding: pad(20.h),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                ShimmerBox(
                  width: double.infinity,
                  height: 84.h,
                  borderRadius: 22.r,
                ),
                SizedBox(height: 12.h),
                ShimmerBox(
                  width: double.infinity,
                  height: 76.h,
                  borderRadius: 22.r,
                ),
                SizedBox(height: 12.h),
                ShimmerBox(
                  width: double.infinity,
                  height: 260.h,
                  borderRadius: 22.r,
                ),
              ],
            ),
          ),
        ),
      ],
      error: (e, _) => [
        SliverPadding(
          padding: pad(40.h),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Text(
                  e is Failure ? e.message : e.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 12.h),
                FilledButton(
                  onPressed: () => ref.invalidate(specialDaysProvider),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emeraldInk,
                    foregroundColor: AppColors.onEmeraldInk,
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ],
      data: (state) {
        if (!state.eligible) {
          return [
            SliverPadding(
              padding: pad(40.h),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Special days aren’t available for this account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: pad(20.h),
            sliver: SliverToBoxAdapter(child: _masterCard(state)),
          ),
          // Her photos, always: she can look at, replace or remove each one,
          // before and while special days run.
          SliverToBoxAdapter(
            key: _photosKey,
            child: _PhotosHeader(count: state.imageCount, active: state.active),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            sliver: SliverToBoxAdapter(
              child: _PhotoGrid(
                tiles: [
                  for (final p in PrayerName.values)
                    _PhotoTile(
                      prayer: p,
                      has: state.hasImage(p),
                      waiting: imagesLoading,
                      image: state.hasImage(p) ? images[p] : null,
                      previewPath: state.hasImage(p) ? previews[p] : null,
                      busy: _busyPrayer == p,
                      disabled: _busyPrayer != null && _busyPrayer != p,
                      attention: _highlightMissing && !state.hasImage(p),
                      onPick: () => _pick(p),
                      onRemove: () => _remove(p),
                    ),
                ],
              ),
            ),
          ),
          // While it runs: the days, with what was logged on each.
          if (SpecialDaysCalendar.of(state) case final calendar?)
            SliverPadding(
              padding: pad(18.h),
              sliver: SliverToBoxAdapter(
                child: SpecialDaysCalendarCard(calendar: calendar),
              ),
            ),
          SliverPadding(
            padding: pad(14.h),
            sliver: SliverToBoxAdapter(child: _InfoCard(state: state)),
          ),
          SliverPadding(
            padding: pad(16.h),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Special days end when you turn them off, or by themselves '
                'after 10 days. Then your usual streak and scoring rules '
                'apply.',
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ];
      },
    );
  }

  /// The one switch: start special days, or (while they run) end them.
  Widget _masterCard(SpecialDays state) {
    final on = state.active;
    final tooSoon = !on && state.isTooSoon(DateTime.now());
    final again = state.canStartAt;
    final String status;
    final Color statusColor;
    if (on) {
      status = 'On — logging your prayers';
      statusColor = AppColors.success;
    } else if (tooSoon && again != null) {
      status = 'You can start again on ${shortDate(again)}';
      statusColor = AppColors.textMuted;
    } else if (state.hasAllImages) {
      status = 'Off — your 5 photos are ready';
      statusColor = AppColors.textMuted;
    } else {
      status =
          'Off — add ${state.missingImages.length} more '
          '${state.missingImages.length == 1 ? 'photo' : 'photos'} to begin';
      statusColor = AppColors.textMuted;
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: on
              ? AppColors.emeraldInk.withValues(alpha: 0.4)
              : AppColors.borderWarm,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: AppColors.worshipAccentBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.borderWarm, width: 1.2.w),
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: 24.sp,
              color: AppColors.worshipAccent,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  on ? 'Special days are on' : 'My special days start today',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                AnimatedText(
                  status,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: on
                ? 'Special days are on. Turn off'
                : 'Start special days today',
            child: Switch.adaptive(
              value: on,
              activeThumbColor: AppColors.emeraldInk,
              onChanged: _toggling || tooSoon
                  ? null
                  : (value) => value ? _start() : _end(),
            ),
          ),
        ],
      ),
    );
  }
}

/// What this is, in the server's words (or ours until it has answered); and,
/// while it runs, what is happening.
class _InfoCard extends StatelessWidget {
  final SpecialDays state;
  const _InfoCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final on = state.active;
    final text = on
        ? 'We’re logging each prayer for you with your photos, so your streak '
              'and scores carry on. Turn the switch off any time.'
              '${state.canStartAt == null ? '' : ' You can start again on ${shortDate(state.canStartAt!)}.'}'
        : state.infoMessage ??
              'Please upload 5 different photos. We’ll share them in your '
                  'groups on your behalf to keep your streak alive, and your '
                  'scores will be counted automatically during your special '
                  'days.';
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: on ? AppColors.quranAccentBg : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            on ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 19.sp,
            color: on ? AppColors.success : AppColors.worshipAccent,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosHeader extends StatelessWidget {
  final int count;
  final bool active;
  const _PhotosHeader({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your 5 photos',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.worshipAccentBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '$count/5',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.worshipAccent,
                  ),
                ),
              ),
            ],
          ),
          if (active) ...[
            SizedBox(height: 4.h),
            Text(
              'You can change these while special days are on. A prayer uses '
              'the photo it has when its time comes.',
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The five photos as a compact grid: three to a row, the last two beneath
/// at the same size.
class _PhotoGrid extends StatelessWidget {
  final List<_PhotoTile> tiles;
  const _PhotoGrid({required this.tiles});

  static const _columns = 3;

  @override
  Widget build(BuildContext context) {
    final gap = 10.w;
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += _columns) {
      final row = tiles.skip(i).take(_columns).toList();
      rows.add(
        Row(
          children: [
            for (var c = 0; c < _columns; c++) ...[
              if (c > 0) SizedBox(width: gap),
              Expanded(
                // A short last row leaves room instead of stretching its tiles.
                child: c < row.length
                    ? AspectRatio(aspectRatio: 0.8, child: row[c])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      if (i + _columns < tiles.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}

/// One prayer's photo as a tile. With a photo: the picture fills the tile, the
/// prayer's name and when it was added sit on it, and round buttons replace or
/// remove it; tapping the picture shows it larger. Without: a dashed tile that
/// invites adding one.
class _PhotoTile extends StatelessWidget {
  final PrayerName prayer;
  final bool has;

  /// The stored photos are still being read, so a photo that has none to show
  /// yet is on its way.
  final bool waiting;

  /// The stored photo with its link, when the server has told us.
  final SpecialDayImage? image;

  /// The file that was sent for this prayer, when this session knows it.
  final String? previewPath;
  final bool busy;
  final bool disabled;
  final bool attention;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoTile({
    required this.prayer,
    required this.has,
    this.waiting = false,
    this.image,
    this.previewPath,
    required this.busy,
    required this.disabled,
    required this.attention,
    required this.onPick,
    required this.onRemove,
  });

  /// What can be drawn: the file picked this session, else the stored photo.
  ImageProvider? get _provider {
    final path = previewPath;
    if (path != null && File(path).existsSync()) return FileImage(File(path));
    final stored = image;
    return stored == null
        ? null
        : CachedNetworkImageProvider(
            stored.url.toString(),
            // A replaced photo has a new time, so it is never served from the
            // old copy.
            cacheKey:
                '${stored.url.path}@${stored.updatedAt.toIso8601String()}',
          );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final radius = BorderRadius.circular(18.r);
    final updated = image?.updatedAt;

    if (!has) {
      return _EmptyTile(
        prayer: prayer,
        busy: busy,
        disabled: disabled,
        attention: attention,
        onPick: onPick,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.worshipAccentBg,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.emeraldInk.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The picture (tap for the large view).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: provider == null
                ? null
                : () => showPhotoViewer(context, prayer, provider),
            // Shimmer while the photo is on its way; plain colour (never an icon
            // behind the photo) if it can't be shown.
            child: provider == null
                ? (waiting ? const _TileShimmer() : const _TilePlain())
                : Image(
                    image: provider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _TilePlain(),
                    frameBuilder: (_, child, frame, sync) =>
                        sync || frame != null ? child : const _TileShimmer(),
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : const _TileShimmer(),
                  ),
          ),
          // Readable text over any photo.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 8.w,
            right: 8.w,
            bottom: 7.h,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prayer.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (updated != null)
                    Text(
                      'Added ${shortDate(updated)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Added: a small tick.
          Positioned(
            top: 7.h,
            left: 7.w,
            child: Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.6),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 12.sp,
                color: Colors.white,
              ),
            ),
          ),
          // Replace and remove.
          Positioned(
            top: 6.h,
            right: 6.w,
            child: Column(
              children: [
                _RoundButton(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Replace ${prayer.label} photo',
                  onPressed: disabled || busy ? null : onPick,
                ),
                SizedBox(height: 6.h),
                _RoundButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Remove ${prayer.label} photo',
                  onPressed: disabled || busy ? null : onRemove,
                ),
              ],
            ),
          ),
          if (busy)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: SizedBox(
                  width: 26.w,
                  height: 26.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The shimmer a photo tile shows while the picture loads.
class _TileShimmer extends StatelessWidget {
  const _TileShimmer();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => ShimmerBox(
      width: c.maxWidth.isFinite ? c.maxWidth : 100,
      height: c.maxHeight.isFinite ? c.maxHeight : 100,
      borderRadius: 0,
    ),
  );
}

/// A photo that can't be shown: just the tile's colour, nothing drawn on it.
class _TilePlain extends StatelessWidget {
  const _TilePlain();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.worshipAccentBg);
}

/// A small round glass button over a photo.
class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.black.withValues(alpha: onPressed == null ? 0.25 : 0.5),
      shape: const CircleBorder(),
      child: InkResponse(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28.w,
          height: 28.w,
          child: Icon(icon, size: 16.sp, color: Colors.white),
        ),
      ),
    ),
  );
}

/// A prayer with no photo yet: a dashed tile that invites adding one.
class _EmptyTile extends StatelessWidget {
  final PrayerName prayer;
  final bool busy;
  final bool disabled;
  final bool attention;
  final VoidCallback onPick;

  const _EmptyTile({
    required this.prayer,
    required this.busy,
    required this.disabled,
    required this.attention,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final color = attention ? AppColors.error : AppColors.worshipAccent;
    return Semantics(
      button: true,
      enabled: !disabled && !busy,
      label: 'Add ${prayer.label} photo',
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _DashedBorder(
          color: color.withValues(alpha: attention ? 0.8 : 0.5),
          radius: 18.r,
        ),
        child: Material(
          color: attention ? AppColors.hadithAccentBg : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18.r),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled || busy ? null : onPick,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 26.w,
                      height: 26.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.emeraldInk,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.all(10.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 34.w,
                              height: 34.w,
                              child: Image.asset(
                                exploreIconAssets['duas']!,
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              prayer.label,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.inkText,
                              ),
                            ),
                            SizedBox(height: 5.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 9.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 14.sp,
                                    color: color,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'Add photo',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                      color: color,
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
          ),
        ),
      ),
    );
  }
}

/// A rounded dashed outline.
class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.8),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

/// What she decided after looking at the photo.
enum PhotoChoice { use, another }

/// Shows the picked photo before it is sent. Resolves with the choice, or null
/// if she backed out.
Future<PhotoChoice?> showPhotoPreview(
  BuildContext context, {
  required PrayerName prayer,
  required String path,
}) => showGroupSheet<PhotoChoice>(
  context,
  (_) => GroupSheetFrame(
    icon: Icons.photo_library_rounded,
    title: '${prayer.label} photo',
    subtitle: 'Check it before it’s used. Each prayer needs a different photo.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 340.h),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                height: 160.h,
                color: AppColors.worshipAccentBg,
                alignment: Alignment.center,
                child: const Text('Couldn’t show this photo'),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Builder(
          builder: (context) => SheetButton(
            label: 'Use this photo',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(PhotoChoice.use),
          ),
        ),
        SizedBox(height: 6.h),
        Builder(
          builder: (context) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(PhotoChoice.another),
                child: const Text('Choose another'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

/// The photo that is stored for [prayer], full size, to look at.
Future<void> showPhotoViewer(
  BuildContext context,
  PrayerName prayer,
  ImageProvider image,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.black,
    insetPadding: EdgeInsets.all(16.w),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        InteractiveViewer(
          child: Image(
            image: image,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Padding(
              padding: EdgeInsets.all(40.w),
              child: const Text(
                'Couldn’t show this photo',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6.h,
          right: 6.w,
          child: IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ],
    ),
  ),
);

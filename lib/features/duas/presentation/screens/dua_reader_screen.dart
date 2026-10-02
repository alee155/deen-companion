import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/dua.dart';
import '../widgets/dua_common.dart';

/// Focused reading view: one dua per page, with adjustable text size,
/// switchable transliteration/translation, a repeat counter and quick
/// copy/share.
class DuaReaderScreen extends ConsumerStatefulWidget {
  final List<Dua> duas;
  final int initialIndex;
  final String? heading;

  const DuaReaderScreen({
    super.key,
    required this.duas,
    required this.initialIndex,
    this.heading,
  });

  @override
  ConsumerState<DuaReaderScreen> createState() => _DuaReaderScreenState();
}

class _DuaReaderScreenState extends ConsumerState<DuaReaderScreen> {
  late final PageController _controller;
  late int _index;
  final Map<int, int> _counts = {};

  static const _scales = [0.85, 1.0, 1.2, 1.45];
  int _scale = 1;
  bool _showTransliteration = true;
  bool _showTranslation = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _logRecent());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Dua get _dua => widget.duas[_index];

  void _logRecent() {
    final d = _dua;
    ref
        .read(recentActivityNotifierProvider.notifier)
        .logActivity(
          RecentActivityItem(
            id: RecentActivityItem.buildId(RecentActivityType.dua, '${d.id}'),
            type: RecentActivityType.dua,
            referenceId: '${d.id}',
            title: d.title,
            subtitle: d.translation,
            route: '/duas',
            viewedAt: DateTime.now(),
          ),
        );
  }

  String _text(Dua d) =>
      '${d.title}\n\n${d.arabic}\n\n${d.transliteration}\n\n${d.translation}\n\n— ${d.source}';

  void _copy(Dua d) {
    Clipboard.setData(ClipboardData(text: _text(d)));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Dua copied'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  void _goTo(int i) {
    if (i < 0 || i >= widget.duas.length) return;
    _controller.animateToPage(
      i,
      duration: context.motion.duration(AppMotion.slow),
      curve: AppMotion.emphasized,
    );
  }

  void _count(Dua d) {
    final n = (_counts[d.id] ?? 0);
    if (n >= d.repeat) {
      setState(() => _counts[d.id] = 0);
      return;
    }
    final next = n + 1;
    next >= d.repeat
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.selectionClick();
    setState(() => _counts[d.id] = next);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duas.length;
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Stack(
        children: [
          // Soft glow at the top.
          Positioned(
            top: -140.h,
            left: -60.w,
            right: -60.w,
            child: IgnorePointer(
              child: Container(
                height: 380.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(total),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: total,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                      _logRecent();
                    },
                    itemBuilder: (_, i) => _page(widget.duas[i]),
                  ),
                ),
                _bottomBar(total),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(int total) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.inkText),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              widget.heading ?? 'Dua',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Reading options',
            icon: Icon(Icons.text_fields_rounded, color: AppColors.inkText),
            onPressed: _showOptions,
          ),
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: FavoriteButton(item: duaFavoriteItem(_dua), size: 22),
          ),
        ],
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet<void>(
      sheetAnimationStyle: AppMotion.sheetStyle,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(VoidCallback f) {
            setState(f);
            setSheet(() {});
          }

          Widget toggle(String label, IconData icon, bool on, VoidCallback t) {
            return SwitchListTile(
              value: on,
              onChanged: (_) => update(t),
              activeThumbColor: AppColors.gold,
              activeTrackColor: AppColors.heroSurface,
              secondary: Icon(icon, color: AppColors.duasAccent),
              title: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkText,
                ),
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: AppColors.parchment,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10.h),
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.borderWarm,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 4.h),
                    child: Row(
                      children: [
                        Text(
                          'Text size',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                        const Spacer(),
                        for (var i = 0; i < _scales.length; i++)
                          Pressable(
                            scale: AppMotion.pressScaleSmall,
                            onTap: () => update(() => _scale = i),
                            child: AnimatedContainer(
                              duration: AppMotion.fast,
                              margin: EdgeInsets.only(left: 8.w),
                              width: 42.w,
                              height: 42.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _scale == i
                                    ? AppColors.heroSurface
                                    : AppColors.surfaceLight,
                                border: Border.all(
                                  color: _scale == i
                                      ? AppColors.gold
                                      : AppColors.borderWarm,
                                ),
                              ),
                              child: Text(
                                'A',
                                style: TextStyle(
                                  fontSize: (12 + i * 3).toDouble(),
                                  fontWeight: FontWeight.w700,
                                  color: _scale == i
                                      ? AppColors.goldLight
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  toggle(
                    'Show transliteration',
                    Icons.translate_rounded,
                    _showTransliteration,
                    () => _showTransliteration = !_showTransliteration,
                  ),
                  toggle(
                    'Show translation',
                    Icons.subject_rounded,
                    _showTranslation,
                    () => _showTranslation = !_showTranslation,
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _page(Dua d) {
    final scale = _scales[_scale];
    final count = _counts[d.id] ?? 0;
    final done = count >= d.repeat;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
      child: Column(
        children: [
          Text(
            d.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
              height: 1.25,
            ),
          ),
          SizedBox(height: 14.h),

          // ── Arabic ──
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
              ),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GeometricPattern(
                    color: AppColors.goldLight.withValues(alpha: 0.06),
                    cell: 40,
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16.sp,
                      color: AppColors.gold,
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      d.arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: kDuaArabicFont,
                        fontSize: 27.sp * scale,
                        height: 2.1,
                        color: AppColors.onHeroSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).appear(key: ValueKey('a${d.id}')),

          // ── Transliteration & translation ──
          if (_showTransliteration && d.transliteration.isNotEmpty) ...[
            SizedBox(height: 16.h),
            _textBlock(
              'TRANSLITERATION',
              d.transliteration,
              15.sp * scale,
              italic: true,
              color: AppColors.duasAccent,
            ),
          ],
          if (_showTranslation && d.translation.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _textBlock('TRANSLATION', d.translation, 15.sp * scale),
          ],

          // ── Source ──
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.duasAccentBg,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 18.sp,
                  color: AppColors.duasAccent,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    d.source,
                    style: TextStyle(
                      fontSize: 12.sp,
                      height: 1.4,
                      color: AppColors.inkText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Counter & actions ──
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Row(
              children: [
                Pressable(
                  onTap: () => _count(d),
                  child: SizedBox(
                    width: 84.w,
                    height: 84.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: count / d.repeat),
                          duration: context.motion.duration(AppMotion.normal),
                          curve: AppMotion.entrance,
                          builder: (_, v, _) => CustomPaint(
                            size: Size.square(84.w),
                            painter: RingPainter(
                              progress: v,
                              track: AppColors.duasAccent.withValues(
                                alpha: 0.15,
                              ),
                              color: done
                                  ? AppColors.gold
                                  : AppColors.duasAccent,
                              width: 5,
                            ),
                          ),
                        ),
                        BumpOnChange(
                          value: count,
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            width: 62.w,
                            height: 62.w,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done
                                  ? AppColors.gold
                                  : AppColors.heroSurface,
                            ),
                            child: IconSwap(
                              child: done
                                  ? Icon(
                                      Icons.check_rounded,
                                      key: const ValueKey('done'),
                                      size: 30.sp,
                                      color: AppColors.heroSurface,
                                    )
                                  : Text(
                                      d.repeat > 1 ? '$count' : 'Ameen',
                                      key: ValueKey('c$count'),
                                      style: TextStyle(
                                        fontSize: d.repeat > 1 ? 22.sp : 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.goldLight,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done
                            ? 'Completed'
                            : d.repeat > 1
                            ? 'Recite ${d.repeat} times'
                            : 'Tap when you finish',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        done ? 'Tap to reset' : '$count of ${d.repeat}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _roundAction(Icons.copy_rounded, () => _copy(d)),
                SizedBox(width: 8.w),
                _roundAction(
                  Icons.ios_share_rounded,
                  () => Share.share(_text(d)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundAction(IconData icon, VoidCallback onTap) {
    return PressScale(
      scale: AppMotion.pressScaleSmall,
      child: InkResponse(
        onTap: onTap,
        radius: 26.w,
        child: Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.parchment,
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Icon(icon, size: 18.sp, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _textBlock(
    String label,
    String text,
    double size, {
    bool italic = false,
    Color? color,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            text,
            style: TextStyle(
              fontSize: size,
              height: 1.65,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              color: color ?? AppColors.inkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(int total) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.borderWarm)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.inkText,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedText(
                  '${_index + 1} of $total',
                  alignment: Alignment.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 6.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.r),
                  child: AnimatedProgressBar(
                    value: (_index + 1) / total,
                    height: 4,
                    fromZero: false,
                    duration: AppMotion.normal,
                    color: AppColors.gold,
                    backgroundColor: AppColors.borderWarm,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _index < total - 1 ? () => _goTo(_index + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.inkText,
          ),
        ],
      ),
    );
  }
}

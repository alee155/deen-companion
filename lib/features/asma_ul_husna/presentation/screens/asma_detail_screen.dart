import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/warm_gradient_scaffold.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/asma_name.dart';
import '../widgets/asma_ornaments.dart';

class AsmaDetailScreen extends ConsumerStatefulWidget {
  final List<AsmaName> names;
  final int initialIndex;

  const AsmaDetailScreen({
    super.key,
    required this.names,
    required this.initialIndex,
  });

  @override
  ConsumerState<AsmaDetailScreen> createState() => _AsmaDetailScreenState();
}

class _AsmaDetailScreenState extends ConsumerState<AsmaDetailScreen> {
  late final PageController _controller;
  late int _currentIndex;

  /// Tasbih counts keep for the lifetime of the screen, per Name number.
  final Map<int, int> _counts = {};
  int _target = 33;

  static const _targets = [3, 7, 33, 99];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _logRecent());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AsmaName get _current => widget.names[_currentIndex];

  FavoriteItem _favoriteItemFor(AsmaName name) {
    return FavoriteItem(
      id: FavoriteItem.buildId(FavoriteContentType.asmaName, '${name.number}'),
      type: FavoriteContentType.asmaName,
      referenceId: '${name.number}',
      title: '${name.transliteration} (${name.english})',
      subtitle: name.meaning,
      route: '/asma-ul-husna',
      savedAt: DateTime.now(),
    );
  }

  void _logRecent() {
    final name = _current;
    ref
        .read(recentActivityNotifierProvider.notifier)
        .logActivity(
          RecentActivityItem(
            id: RecentActivityItem.buildId(
              RecentActivityType.asmaName,
              '${name.number}',
            ),
            type: RecentActivityType.asmaName,
            referenceId: '${name.number}',
            title: '${name.transliteration} (${name.english})',
            subtitle: name.meaning,
            route: '/asma-ul-husna',
            viewedAt: DateTime.now(),
          ),
        );
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.names.length) return;
    _controller.animateToPage(
      index,
      duration: context.motion.duration(AppMotion.slow),
      curve: AppMotion.emphasized,
    );
  }

  void _tap(AsmaName name) {
    final next = (_counts[name.number] ?? 0) + 1;
    if (next == _target) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() => _counts[name.number] = next);
  }

  String _shareText(AsmaName n) =>
      '${n.arabic}\n${n.transliteration} — ${n.english}\n\n${n.meaning}';

  void _copy(AsmaName n) {
    Clipboard.setData(ClipboardData(text: _shareText(n)));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.names.length;
    final tint = AsmaTint.of(_current.number);

    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            // Ambient tint that shifts as you move between Names.
            Positioned(
              top: -120.h,
              left: -60.w,
              right: -60.w,
              child: AnimatedContainer(
                duration: context.motion.duration(AppMotion.slow),
                height: 420.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tint.accent.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
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
                        setState(() => _currentIndex = i);
                        _logRecent();
                      },
                      itemBuilder: (context, index) =>
                          _page(widget.names[index]),
                    ),
                  ),
                  _bottomBar(total),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(int total) {
    final tint = AsmaTint.of(_current.number);
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.inkText),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          ContentSwitcher(
            duration: AppMotion.fast,
            alignment: Alignment.center,
            child: Container(
              key: ValueKey(_current.number),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: tint.bg,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: tint.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Name ${_current.number} of 99',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: tint.accent,
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.ios_share_rounded,
              color: AppColors.textMuted,
              size: 20.sp,
            ),
            onPressed: () => Share.share(_shareText(_current)),
          ),
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: FavoriteButton(item: _favoriteItemFor(_current), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _page(AsmaName name) {
    final tint = AsmaTint.of(name.number);
    final count = _counts[name.number] ?? 0;
    final reached = count >= _target;
    final progress = (count / _target).clamp(0.0, 1.0);
    final seq = RevealSequence(start: const Duration(milliseconds: 120));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
      child: Column(
        children: [
          // ── Medallion ──
          SizedBox(
            width: 250.w,
            height: 250.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(250.w),
                  painter: StarPainter(
                    fill: Colors.transparent,
                    stroke: AppColors.gold.withValues(alpha: 0.45),
                    strokeWidth: 1,
                    rotation: 0.3927, // 22.5°
                    inner: 0.8,
                  ),
                ),
                SizedBox(
                  width: 220.w,
                  height: 220.w,
                  child: CustomPaint(
                    painter: StarPainter(
                      fill: AppColors.heroSurface,
                      stroke: AppColors.gold,
                      strokeWidth: 1.6,
                      inner: 0.78,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipPath(
                          clipper: _StarClipper(),
                          child: SizedBox.expand(
                            child: GeometricPattern(
                              color: AppColors.goldLight.withValues(
                                alpha: 0.10,
                              ),
                              cell: 30,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 36.w),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name.arabic,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: kAsmaArabicFont,
                                fontSize: 56.sp,
                                color: AppColors.goldLight,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: StarBadge(
                    label: '${name.number}',
                    size: 40.w,
                    fill: AppColors.gold,
                    stroke: AppColors.parchment,
                    textColor: AppColors.heroSurface,
                  ),
                ),
              ],
            ),
          ).celebrate(key: ValueKey('m${name.number}')),
          SizedBox(height: 16.h),
          Text(
            name.transliteration,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
              height: 1.1,
            ),
          ).slideIn(RevealDirection.bottom, delay: seq.next()),
          SizedBox(height: 6.h),
          Text(
            name.english,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: tint.accent,
            ),
          ).slideIn(RevealDirection.top, delay: seq.next()),
          SizedBox(height: 20.h),

          // ── Meaning ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      color: tint.accent,
                      size: 26.sp,
                    ).slideIn(RevealDirection.topStart, delay: seq.next()),
                    SizedBox(width: 6.w),
                    Text(
                      'MEANING',
                      style: TextStyle(
                        fontSize: 11.sp,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: tint.accent,
                      ),
                    ).slideIn(RevealDirection.top, delay: seq.next()),
                    const Spacer(),
                    PressScale(
                      scale: AppMotion.pressScaleSmall,
                      child: InkResponse(
                        onTap: () => _copy(name),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 18.sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  name.meaning,
                  style: TextStyle(
                    fontSize: 15.sp,
                    height: 1.7,
                    color: AppColors.inkText,
                  ),
                ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
              ],
            ),
          ),
          SizedBox(height: 14.h),

          // ── Tasbih counter ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: tint.bg,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: tint.accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Pressable(
                  onTap: () => _tap(name),
                  child: SizedBox(
                    width: 108.w,
                    height: 108.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: progress),
                          duration: context.motion.duration(AppMotion.normal),
                          curve: AppMotion.entrance,
                          builder: (_, v, _) => CustomPaint(
                            size: Size.square(108.w),
                            painter: RingPainter(
                              progress: v,
                              track: tint.accent.withValues(alpha: 0.18),
                              color: reached ? AppColors.gold : tint.accent,
                            ),
                          ),
                        ),
                        BumpOnChange(
                          value: count,
                          child: AnimatedContainer(
                            duration: context.motion.duration(AppMotion.fast),
                            width: 82.w,
                            height: 82.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: reached
                                  ? AppColors.gold
                                  : AppColors.heroSurface,
                            ),
                            alignment: Alignment.center,
                            child: IconSwap(
                              child: reached
                                  ? Icon(
                                      Icons.check_rounded,
                                      key: const ValueKey('done'),
                                      size: 36.sp,
                                      color: AppColors.heroSurface,
                                    )
                                  : Text(
                                      '$count',
                                      key: const ValueKey('count'),
                                      style: TextStyle(
                                        fontSize: 28.sp,
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
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedText(
                        reached ? 'Target reached' : 'Tap to recite',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      AnimatedText(
                        '$count of $_target',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: [
                          for (final t in _targets)
                            Pressable(
                              scale: AppMotion.pressScaleSmall,
                              onTap: () => setState(() => _target = t),
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  color: t == _target
                                      ? tint.accent
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: tint.accent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '$t',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: t == _target
                                        ? AppColors.surfaceLight
                                        : tint.accent,
                                  ),
                                ),
                              ),
                            ),
                          Pressable(
                            scale: AppMotion.pressScaleSmall,
                            onTap: () =>
                                setState(() => _counts[name.number] = 0),
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Icon(
                                Icons.restart_alt_rounded,
                                size: 20.sp,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).slideIn(
            RevealDirection.bottom,
            delay: const Duration(milliseconds: 260),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(int total) {
    final tint = AsmaTint.of(_current.number);
    final canSlide = total > 1;
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.borderWarm)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _currentIndex > 0
                ? () => _goTo(_currentIndex - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.inkText,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: tint.accent,
                inactiveTrackColor: AppColors.borderWarm,
                thumbColor: AppColors.gold,
                overlayColor: tint.accent.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                min: 0,
                max: canSlide ? (total - 1).toDouble() : 1,
                value: canSlide ? _currentIndex.toDouble() : 0,
                onChanged: canSlide
                    ? (v) => _controller.jumpToPage(v.round())
                    : null,
              ),
            ),
          ),
          IconButton(
            onPressed: _currentIndex < total - 1
                ? () => _goTo(_currentIndex + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.inkText,
          ),
        ],
      ),
    );
  }
}

class _StarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => eightStarPath(
    size.center(Offset.zero),
    size.shortestSide / 2 - 2,
    inner: 0.78,
  );

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

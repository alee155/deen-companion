import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../domain/entities/islamic_name.dart';

/// A name's full detail — hero, quick facts, meaning, root letters, a note,
/// and same-gender names to keep exploring. [pool] is whatever list the hub
/// was showing when this name was opened (already gender/origin/search
/// filtered), so "shuffle" and "more names" both stay within it.
class IslamicNameDetailScreen extends ConsumerStatefulWidget {
  final IslamicName name;
  final List<IslamicName> pool;

  const IslamicNameDetailScreen({
    super.key,
    required this.name,
    required this.pool,
  });

  @override
  ConsumerState<IslamicNameDetailScreen> createState() =>
      _IslamicNameDetailScreenState();
}

class _IslamicNameDetailScreenState
    extends ConsumerState<IslamicNameDetailScreen> {
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  IslamicName get name => widget.name;
  bool get _isMale => name.gender == 'male';
  Color get _accent => _isMale ? AppColors.boyAccent : AppColors.girlAccent;
  Color get _accentBg =>
      _isMale ? AppColors.boyAccentBg : AppColors.girlAccentBg;
  String get _imagePath =>
      _isMale ? 'assets/images/boy_name.png' : 'assets/images/girl_name.jpeg';

  FavoriteItem get _favorite => FavoriteItem(
    id: FavoriteItem.buildId(FavoriteContentType.islamicName, '${name.id}'),
    type: FavoriteContentType.islamicName,
    referenceId: '${name.id}',
    title: name.name,
    subtitle: name.meaning,
    route: '/islamic-names',
    savedAt: DateTime.now(),
  );

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

  void _openOther(IslamicName other) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IslamicNameDetailScreen(name: other, pool: widget.pool),
      ),
    );
  }

  void _shuffle() {
    if (widget.pool.length < 2) return;
    HapticFeedback.selectionClick();
    IslamicName random;
    do {
      random = widget.pool[Random().nextInt(widget.pool.length)];
    } while (random.id == name.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            IslamicNameDetailScreen(name: random, pool: widget.pool),
      ),
    );
  }

  void _share() {
    Share.share(
      '${name.name} (${name.arabic}) — ${name.meaning}.\n'
      'Discover more Islamic names in Deen Companion.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootLetters =
        name.root?.split(' ').where((s) => s.isNotEmpty).toList() ??
        const <String>[];
    final moreNames = widget.pool
        .where((n) => n.gender == name.gender && n.id != name.id)
        .take(10)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _hero()),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          Expanded(
                            child: _FactChip(
                              icon: _isMale
                                  ? Icons.male_rounded
                                  : Icons.female_rounded,
                              label: 'Gender',
                              value: _isMale ? 'Boy' : 'Girl',
                            ).slideIn(RevealDirection.start, distance: 20),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child:
                                _FactChip(
                                  icon: Icons.public_rounded,
                                  label: 'Origin',
                                  value: name.origin.isEmpty
                                      ? '—'
                                      : name.origin,
                                ).slideIn(
                                  RevealDirection.bottom,
                                  delay: const Duration(milliseconds: 60),
                                ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child:
                                _FactChip(
                                  icon: Icons.auto_awesome_rounded,
                                  label: 'Root',
                                  value: rootLetters.isEmpty
                                      ? '—'
                                      : '${rootLetters.length} letters',
                                ).slideIn(
                                  RevealDirection.end,
                                  distance: 20,
                                  delay: const Duration(milliseconds: 120),
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _Section(
                        icon: Icons.lightbulb_outline_rounded,
                        title: 'Meaning',
                        child: Text(
                          name.meaning,
                          style: TextStyle(
                            fontSize: 15.sp,
                            height: 1.55,
                            color: AppColors.inkText,
                          ),
                        ),
                      ).slideIn(RevealDirection.bottom, onVisible: true),
                      if (rootLetters.isNotEmpty) ...[
                        SizedBox(height: 14.h),
                        _Section(
                          icon: Icons.translate_rounded,
                          title: 'Root letters',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final entry in rootLetters.indexed)
                                Container(
                                  margin: EdgeInsets.symmetric(horizontal: 5.w),
                                  width: 48.w,
                                  height: 48.w,
                                  // alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.worshipAccentBg,
                                    borderRadius: BorderRadius.circular(15.r),
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 10.h),
                                      child: Text(
                                        entry.$2,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          fontFamily: 'AmiriQuran',
                                          fontSize: 22.sp,
                                          color: AppColors.worshipAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ).slideIn(
                                  RevealDirection.bottom,
                                  delay: Duration(milliseconds: 60 * entry.$1),
                                  distance: 16,
                                  onVisible: true,
                                ),
                            ],
                          ),
                        ).slideIn(RevealDirection.bottom, onVisible: true),
                      ],
                      if (name.note.isNotEmpty) ...[
                        SizedBox(height: 14.h),
                        _Section(
                          icon: Icons.auto_stories_rounded,
                          title: 'Good to know',
                          child: Text(
                            name.note,
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              height: 1.6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ).slideIn(RevealDirection.bottom, onVisible: true),
                      ],
                      SizedBox(height: 18.h),
                      PressScale(
                        child: SizedBox(
                          width: double.infinity,
                          height: 52.h,
                          child: FilledButton.icon(
                            onPressed: _shuffle,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.emeraldInk,
                              foregroundColor: AppColors.onEmeraldInk,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18.r),
                              ),
                            ),
                            icon: const Icon(Icons.shuffle_rounded),
                            label: Text(
                              'Another random name',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ).slideIn(RevealDirection.bottom, onVisible: true),
                    ]),
                  ),
                ),
                if (moreNames.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 26.h, 20.w, 12.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isMale
                                  ? "More boys' names"
                                  : "More girls' names",
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkText,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.worshipAccentBg,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '${moreNames.length}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.worshipAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 128.h,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        itemCount: moreNames.length,
                        itemBuilder: (context, index) => Padding(
                          padding: EdgeInsets.only(
                            right: index == moreNames.length - 1 ? 0 : 10.w,
                          ),
                          child: _MoreNameCard(
                            name: moreNames[index],
                            accent: _accent,
                            accentBg: _accentBg,
                            onTap: () => _openOther(moreNames[index]),
                          ).slideInAt(index, distance: 18),
                        ),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 32.h,
                  ),
                ),
              ],
            ),
            Positioned(top: 0, left: 0, right: 0, child: _pinnedBar()),
          ],
        ),
      ),
    );
  }

  /// Pinned bar: back, the name once scrolled, then favourite + share.
  Widget _pinnedBar() {
    final isFavorite = ref.watch(isFavoriteProvider(_favorite.id));
    return ValueListenableBuilder<double>(
      valueListenable: _bar,
      builder: (context, raw, _) {
        final t = (raw * 2.5).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.heroSurface.withValues(alpha: t),
            boxShadow: t > 0.6
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18 * t),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 8.h),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    strength: t,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Opacity(
                      opacity: t,
                      child: Text(
                        name.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  GlassIconButton(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    tooltip: isFavorite ? 'Remove favourite' : 'Favourite',
                    strength: t,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(favoritesNotifierProvider.notifier)
                          .toggle(_favorite);
                    },
                  ),
                  SizedBox(width: 8.w),
                  GlassIconButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Share',
                    strength: t,
                    onPressed: _share,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hero() {
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
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + 64.h,
              24.w,
              26.h,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 104.w,
                    height: 104.w,
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceLight,
                      border: Border.all(
                        color: AppColors.emeraldInk,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldInk.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(_imagePath, fit: BoxFit.cover),
                    ),
                  ).popIn(),
                  SizedBox(height: 16.h),
                  Text(
                    name.arabic,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 38.sp,
                      height: 1.3,
                      color: AppColors.goldLight,
                    ),
                  ).slideIn(
                    RevealDirection.top,
                    delay: const Duration(milliseconds: 100),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    name.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 32.sp,
                      letterSpacing: 0.5,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ).slideIn(
                    RevealDirection.bottom,
                    delay: const Duration(milliseconds: 160),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    name.meaning,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      height: 1.45,
                      color: AppColors.onHeroSurface.withValues(alpha: 0.8),
                    ),
                  ).appear(delay: const Duration(milliseconds: 240)),
                  SizedBox(height: 14.h),
                  FeatureHeroChip(
                    _isMale ? Icons.male_rounded : Icons.female_rounded,
                    _isMale ? 'Boy name' : 'Girl name',
                  ).build().appear(delay: const Duration(milliseconds: 300)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled content block in the app's bordered-card style.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(14.w),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(22.r),
      border: Border.all(color: AppColors.borderWarm),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: AppColors.worshipAccentBg,
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(icon, size: 17.sp, color: AppColors.worshipAccent),
            ),
            SizedBox(width: 10.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        child,
      ],
    ),
  );
}

class _FactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FactChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 6.w),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(18.r),
      border: Border.all(color: AppColors.borderWarm),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.worshipAccent, size: 20.sp),
        SizedBox(height: 6.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.inkText,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

class _MoreNameCard extends StatelessWidget {
  final IslamicName name;
  final Color accent;
  final Color accentBg;
  final VoidCallback onTap;

  const _MoreNameCard({
    required this.name,
    required this.accent,
    required this.accentBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => PressScale(
    child: Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(22.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 140.w,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                  ),
                  Text(
                    name.arabic,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 15.sp,
                      color: accent,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                name.meaning,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

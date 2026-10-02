import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/domain/explore_icon_assets.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/daily_content_selector.dart';
import '../providers/daily_content_providers.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../widgets/daily_reading_section.dart';

/// The Ayat & Hadith of the Day for one day. Opened from the notification
/// (tray or in-app list), so [notificationId] identifies which one.
class DailyContentScreen extends ConsumerStatefulWidget {
  final String? notificationId;
  const DailyContentScreen({super.key, this.notificationId});

  @override
  ConsumerState<DailyContentScreen> createState() => _DailyContentScreenState();
}

class _DailyContentScreenState extends ConsumerState<DailyContentScreen> {
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);
  late final String _dateKey;

  @override
  void initState() {
    super.initState();
    final id = widget.notificationId;
    _dateKey = id == null
        ? DailyContentSelector.dateKey(DateTime.now())
        : dateKeyForNotificationId(ref.read(dailyContentStoreProvider), id);
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 140 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _bar.value) _bar.value = t;
    });
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(notificationHistoryProvider.notifier).markRead(id);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(dailyContentProvider(_dateKey));
    final date = DailyContentSelector.parseDateKey(_dateKey);
    final subtitle = date == null
        ? 'Your daily reading'
        : DateFormat('EEEE, d MMMM y').format(date);

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
                SliverToBoxAdapter(
                  child: FeatureHero(
                    title: 'Ayat & Hadith\nof the Day',
                    subtitle: subtitle,
                    ghostIcon: Icons.menu_book_rounded,
                    chips: content.maybeWhen(
                      data: (d) => [
                        FeatureHeroChip(
                          Icons.menu_book_rounded,
                          'Surah ${d.ayah.surahNameEnglish} · ${d.ayah.verseKey}',
                        ),
                        FeatureHeroChip(
                          Icons.auto_stories_rounded,
                          '${d.hadith.collectionName} · #${d.hadith.hadithNumber}',
                        ),
                      ],
                      orElse: () => const [],
                    ),
                  ),
                ),
                ...content.when(
                  loading: _loading,
                  error: (error, _) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40.h),
                        child: FailureView(
                          failure: failureFrom(error),
                          onRetry: () async =>
                              ref.invalidate(dailyContentProvider(_dateKey)),
                        ),
                      ),
                    ),
                  ],
                  data: (data) => [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          DailyReadingSection(
                            iconAsset: exploreIconAssets['quran']!,
                            title: 'Ayat of the Day',
                            source:
                                'Surah ${data.ayah.surahNameEnglish} · '
                                '${data.ayah.surahNameArabic} · '
                                'Ayah ${data.ayah.verseKey}',
                            arabic: data.ayah.arabic,
                            translation: data.ayah.translation,
                            onShare: () => Share.share(data.ayah.toShareText()),
                          ).slideIn(RevealDirection.bottom, distance: 18),
                          SizedBox(height: 16.h),
                          DailyReadingSection(
                            iconAsset: exploreIconAssets['hadith']!,
                            title: 'Hadith of the Day',
                            source:
                                '${data.hadith.collectionName} · '
                                'Hadith ${data.hadith.hadithNumber}',
                            arabic: data.hadith.hasArabic
                                ? data.hadith.arabic
                                : null,
                            translation: data.hadith.english,
                            badge: data.hadith.grade.trim().isEmpty
                                ? null
                                : 'Grade: ${data.hadith.grade.trim()}',
                            onShare: () =>
                                Share.share(data.hadith.toShareText()),
                          ).slideIn(
                            RevealDirection.bottom,
                            distance: 18,
                            delay: const Duration(milliseconds: 90),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 40.h,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(opacity: _bar, title: 'Ayat & Hadith'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _loading() => [
    SliverPadding(
      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
      sliver: SliverList.separated(
        itemCount: 2,
        separatorBuilder: (_, _) => SizedBox(height: 16.h),
        itemBuilder: (_, _) => ShimmerBox(
          width: double.infinity,
          height: 280.h,
          borderRadius: 22.r,
        ),
      ),
    ),
  ];
}

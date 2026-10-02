import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/location/location_service.dart';
import '../../../audio_player/domain/audio_track.dart';
import '../../../reliability_setup/domain/reliability_requirement.dart';
import '../../../reliability_setup/presentation/providers/reliability_providers.dart';
import '../../../reliability_setup/presentation/widgets/reliability_banner.dart';
import '../../../reliability_setup/presentation/widgets/reliability_setup_sheet.dart';
import '../../../daily_content/presentation/providers/daily_notification_service.dart';
import '../../../audio_player/presentation/providers/audio_player_provider.dart';
import '../../../quran/domain/entities/surah_summary.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../providers/home_recitations_provider.dart';
import '../widgets/home_category_grid.dart';
import '../widgets/home_recitation_list.dart';
import '../widgets/home_slider_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    // Router is live and Home is on screen: deliver any notification tap
    // queued during launch and (once) ask for notification permission.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startUp());
  }

  /// Home is the moment to ask for everything reminders and notifications
  /// need, so no alert ever fails later because of a missing permission.
  Future<void> _startUp() async {
    await ref.read(dailyNotificationServiceProvider).onHomeReady();

    // Android drops a permission request made while another dialog is up,
    // and Home's prayer times ask for location on their own — so wait for
    // that prompt to settle (this joins it rather than racing it).
    await ref.read(locationServiceProvider).requestPermission();
    if (!mounted) return;

    final reliability = ref.read(reliabilityServiceProvider);
    final status = await reliability.check();
    ref.invalidate(reliabilityStatusProvider);
    if (!mounted || status.allGranted || !reliability.shouldPrompt()) return;

    await reliability.markPrompted();
    if (mounted) await showReliabilitySetupSheet(context);
  }

  void _playRecitation(SurahSummary surah) {
    ref
        .read(audioPlayerNotifierProvider.notifier)
        .playTrack(
          AudioTrack(
            id: 'surah-${surah.number}',
            titleEnglish: surah.nameEnglish,
            titleArabic: surah.nameArabic,
            reciterName: 'Mishary Rashid Alafasy',
            url: surah.exampleAudioUrl,
          ),
        );
    ref
        .read(recentActivityNotifierProvider.notifier)
        .logActivity(
          RecentActivityItem(
            id: RecentActivityItem.buildId(
              RecentActivityType.surah,
              '${surah.number}',
            ),
            type: RecentActivityType.surah,
            referenceId: '${surah.number}',
            title: surah.nameEnglish,
            subtitle: surah.nameArabic,
            route: '/quran',
            viewedAt: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final recitationsAsync = ref.watch(featuredRecitationsProvider);
    final seq = RevealSequence(start: const Duration(milliseconds: 140));

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 340.h,
            child: HomeSliderHeader(
              height: 340.h,
              onAvatarTap: () => context.go('/profile'),
            ),
          ),
          Positioned(
            top: 300.h,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.parchment,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 110.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 5.h,
                        width: 50.w,
                        decoration: BoxDecoration(
                          color: AppColors.borderWarm,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 22.h),
                    const ReliabilityBanner(),
                    _SectionHeader(
                      title: 'Categories',
                      onSeeAll: () => context.push('/explore'),
                      seq: seq,
                      titleDirection: RevealDirection.bottomStart,
                      actionDirection: RevealDirection.topEnd,
                    ),
                    SizedBox(height: 14.h),
                    HomeCategoryGrid(
                      selectedIndex: _selectedCategoryIndex,
                      onSelected: (index) {
                        setState(() => _selectedCategoryIndex = index);
                        context.push(homeCategories[index].route);
                      },
                    ),
                    SizedBox(height: 28.h),
                    _SectionHeader(
                      title: 'Recitations',
                      onSeeAll: () => context.push('/quran'),
                      seq: seq,
                      titleDirection: RevealDirection.end,
                      actionDirection: RevealDirection.bottomEnd,
                    ),
                    SizedBox(height: 14.h),
                    ContentSwitcher(
                      child: KeyedSubtree(
                        key: ValueKey(recitationsAsync.hasValue),
                        child: recitationsAsync.when(
                          data: (surahs) => HomeRecitationList(
                            surahs: surahs,
                            onTap: _playRecitation,
                          ),
                          loading: () => SizedBox(
                            height: 130.h,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.emeraldInk,
                              ),
                            ),
                          ),
                          error: (_, _) => SizedBox(
                            height: 60.h,
                            child: Center(
                              child: Text(
                                'Recitations unavailable',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ).slideIn(RevealDirection.top),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // const BannerAdWidget(
                    //   margin: EdgeInsets.symmetric(vertical: 4),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  final RevealSequence seq;
  final RevealDirection titleDirection;
  final RevealDirection actionDirection;

  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    required this.seq,
    required this.titleDirection,
    required this.actionDirection,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        seq.wrap(
          Text(
            title,
            style: AppTypography.headline.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          direction: titleDirection,
        ),
        Pressable(
          onTap: onSeeAll,
          scale: AppMotion.pressScaleSmall,
          child: Text(
            'See All',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.emeraldInk,
            ),
          ),
        ).slideIn(
          actionDirection,
          delay: seq.next(),
          duration: AppMotion.normal,
          distance: 16,
        ),
      ],
    );
  }
}

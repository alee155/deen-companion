import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../providers/mutashabihat_providers.dart';
import '../widgets/ayah_picker_sheet.dart';
import '../widgets/surah_picker_sheet.dart';
import 'mutashabihat_comparison_screen.dart';
import 'mutashabihat_surah_list_screen.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

/// Landing page for Mutashabihat: a short intro, the feature's headline
/// numbers, and the three ways into a comparison — a random pair to drill,
/// a chosen surah to browse, or a specific ayah to look up.
class MutashabihatHubScreen extends ConsumerWidget {
  const MutashabihatHubScreen({super.key});

  Future<void> _randomPractice(BuildContext context, WidgetRef ref) async {
    await ref.read(mutashabihatRandomNotifierProvider.notifier).next();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const _RandomPracticeScreen()),
    );
  }

  Future<void> _browseBySurah(BuildContext context, WidgetRef ref) async {
    final surah = await showSurahPickerSheet(context, ref);
    if (surah == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MutashabihatSurahListScreen(
          surah: surah.number,
          surahName: surah.nameEnglish,
        ),
      ),
    );
  }

  Future<void> _lookUpVerse(BuildContext context, WidgetRef ref) async {
    final surah = await showSurahPickerSheet(context, ref);
    if (surah == null || !context.mounted) return;

    final ayah = await showAyahPickerSheet(context, surah: surah);
    if (ayah == null || !context.mounted) return;

    try {
      final result = await ref.read(
        mutashabihatByAyahNotifierProvider((surah.number, ayah)).future,
      );
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MutashabihatComparisonScreen(entry: result),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${surah.nameEnglish} $ayah has no known lookalikes.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(mutashabihatInfoNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: const DeenAppBar(title: 'Mutashabihat', subtitle: 'متشابهات'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
        children: [
          const _Intro(),
          SizedBox(height: 18.h),
          infoAsync.when(
            data: (info) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ).slideIn(
                  RevealDirection.bottomStart,
                  delay: const Duration(milliseconds: 160),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child:
                          _StatChip(
                            icon: Icons.menu_book_outlined,
                            value: '${info.totalEntries}',
                            label: 'Verses',
                          ).slideIn(
                            RevealDirection.start,
                            delay: const Duration(milliseconds: 220),
                            distance: 20,
                          ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child:
                          _StatChip(
                            icon: Icons.compare_arrows_rounded,
                            value: '${info.totalPairs}',
                            label: 'Pairs',
                          ).slideIn(
                            RevealDirection.bottom,
                            delay: const Duration(milliseconds: 280),
                          ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child:
                          _StatChip(
                            icon: Icons.auto_stories_outlined,
                            value: '${info.surahsInvolved}',
                            label: 'Surahs',
                          ).slideIn(
                            RevealDirection.end,
                            delay: const Duration(milliseconds: 340),
                            distance: 20,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const _StatsSkeleton(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          SizedBox(height: 22.h),
          OrnamentDivider(ruleWidth: 30.w),
          SizedBox(height: 18.h),
          _ActionCard(
            icon: Icons.shuffle_rounded,
            accent: AppColors.amber,
            accentBg: AppColors.amber.withValues(alpha: 0.14),
            title: 'Random Practice',
            subtitle: 'Drill a random pair of confusable verses',
            onTap: () => _randomPractice(context, ref),
          ).slideIn(
            RevealDirection.start,
            delay: const Duration(milliseconds: 380),
            onVisible: true,
          ),
          SizedBox(height: 12.h),
          _ActionCard(
            icon: Icons.menu_book_outlined,
            accent: AppColors.quranAccent,
            accentBg: AppColors.quranAccentBg,
            title: 'Browse by Surah',
            subtitle: 'See confusable verses within one surah',
            onTap: () => _browseBySurah(context, ref),
          ).slideIn(
            RevealDirection.end,
            delay: const Duration(milliseconds: 440),
            onVisible: true,
          ),
          SizedBox(height: 12.h),
          _ActionCard(
            icon: Icons.search_rounded,
            accent: AppColors.gold,
            accentBg: AppColors.goldLight,
            title: 'Look Up a Verse',
            subtitle: 'Check if a specific ayah has known lookalikes',
            onTap: () => _lookUpVerse(context, ref),
          ).slideIn(
            RevealDirection.bottom,
            delay: const Duration(milliseconds: 500),
            onVisible: true,
          ),
          SizedBox(height: 20.h),
          const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final seq = RevealSequence();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Similar Verses',
                style: AppTypography.heroSerif.copyWith(
                  fontSize: 22.sp,
                  color: AppColors.inkText,
                ),
              ).slideIn(RevealDirection.topStart, delay: seq.next()),
              SizedBox(height: 6.h),
              Text(
                "Verses across the Quran that read almost the same — the "
                'ones reciters most often mix up. Compare them side by side '
                'and see exactly what differs.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
            ],
          ),
        ),
        SizedBox(width: 14.w),
        Opacity(
          opacity: 0.92,
          child: Image.asset(
            'assets/images/mutashabihat.png',
            width: 64.w,
            height: 64.w,
            fit: BoxFit.contain,
          ),
        ).slideIn(RevealDirection.topEnd, delay: seq.next()),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.quranAccent),
          SizedBox(height: 6.h),
          Text(
            value,
            style: AppTypography.headline.copyWith(
              fontSize: 16.sp,
              color: AppColors.inkText,
            ),
          ),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i != 0) SizedBox(width: 10.w),
          Expanded(
            child: ShimmerBox(
              width: double.infinity,
              height: 74.h,
              borderRadius: 14.r,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Row(
              children: [
                Container(
                  width: 46.w,
                  height: 46.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                  child: Icon(icon, color: accent, size: 22.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RandomPracticeScreen extends ConsumerWidget {
  const _RandomPracticeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(mutashabihatRandomNotifierProvider);

    return entryAsync.when(
      data: (entry) {
        if (entry == null) {
          return const Scaffold(body: _RandomPracticeSkeleton());
        }
        return MutashabihatComparisonScreen(
          entry: entry,
          onNext: () =>
              ref.read(mutashabihatRandomNotifierProvider.notifier).next(),
        );
      },
      loading: () => const Scaffold(body: _RandomPracticeSkeleton()),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.parchment,
        appBar: const DeenAppBar(title: 'Random Practice'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: FailureView(
              failure: failureFrom(error),
              onRetry: () async =>
                  ref.read(mutashabihatRandomNotifierProvider.notifier).next(),
            ),
          ),
        ),
      ),
    );
  }
}

class _RandomPracticeSkeleton extends StatelessWidget {
  const _RandomPracticeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShimmerBox(
              width: double.infinity,
              height: 200.h,
              borderRadius: 18.r,
            ),
            SizedBox(height: 20.h),
            ShimmerBox(width: 160.w, height: 14.h, borderRadius: 4.r),
            SizedBox(height: 14.h),
            ShimmerBox(
              width: double.infinity,
              height: 130.h,
              borderRadius: 16.r,
            ),
          ],
        ),
      ),
    );
  }
}

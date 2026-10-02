import 'package:deen_companion/core/motion/motion.dart';
import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../domain/entities/mutashabihat_entry.dart';
import '../widgets/highlighted_arabic_text.dart';
import '../widgets/mutashabihat_base_verse_card.dart';
import '../widgets/mutashabihat_similar_verse_card.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

/// The core comparison experience: the anchor verse, then every verse it
/// gets confused with, each one's differing words picked out against the
/// anchor. Reused for all three ways into a comparison — random practice,
/// browsing a surah, and looking up a specific ayah.
class MutashabihatComparisonScreen extends StatefulWidget {
  final MutashabihatEntry entry;
  final VoidCallback? onNext; // only wired for random-practice mode

  const MutashabihatComparisonScreen({
    super.key,
    required this.entry,
    this.onNext,
  });

  @override
  State<MutashabihatComparisonScreen> createState() =>
      _MutashabihatComparisonScreenState();
}

class _MutashabihatComparisonScreenState
    extends State<MutashabihatComparisonScreen> {
  bool _quizMode = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final count = entry.similarVerses.length;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: DeenAppBar(
        title: 'Compare Verses',
        subtitle: '${entry.verse.surahNameEnglish} · ${entry.verse.verseKey}',
        actions: [
          IconButton(
            tooltip: _quizMode
                ? 'Quiz mode on — tap to turn off'
                : 'Quiz mode off — tap to hide lookalikes',
            icon: Icon(
              _quizMode
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_outlined,
              color: _quizMode ? AppColors.amberDeep : AppColors.textMuted,
            ),
            onPressed: () => setState(() => _quizMode = !_quizMode),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        children: [
          MutashabihatBaseVerseCard(
            verse: entry.verse,
            otherArabic: [for (final v in entry.similarVerses) v.arabic],
          ).slideIn(RevealDirection.top, distance: 18),
          SizedBox(height: 22.h),
          Row(
            children: [
              Icon(
                Icons.call_split_rounded,
                size: 15.sp,
                color: AppColors.textMuted,
              ).slideIn(
                RevealDirection.bottomStart,
                delay: const Duration(milliseconds: 100),
              ),
              SizedBox(width: 6.w),
              Text(
                '$count similar verse${count == 1 ? '' : 's'} elsewhere in the Quran',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ).slideIn(
                RevealDirection.end,
                delay: const Duration(milliseconds: 140),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          const DiffLegend().slideIn(
            RevealDirection.bottomEnd,
            delay: const Duration(milliseconds: 200),
          ),
          ...entry.similarVerses.indexed.map(
            (e) => MutashabihatSimilarVerseCard(
              key: ValueKey(e.$2.verseKey),
              verse: e.$2,
              baseArabic: entry.verse.arabic,
              startHidden: _quizMode,
            ).slideInAt(e.$1 + 1),
          ),
          SizedBox(height: 20.h),
          OrnamentDivider(ruleWidth: 30.w),
          SizedBox(height: 16.h),
          const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),
          if (widget.onNext != null) ...[
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onNext,
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Next random pair'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldInk,
                  foregroundColor: AppColors.onEmeraldInk,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ).slideIn(RevealDirection.bottom, onVisible: true),
          ],
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/seal_number_badge.dart';
import '../../domain/entities/mutashabihat_verse_ref.dart';
import '../utils/arabic_diff.dart';
import 'highlighted_arabic_text.dart';

String _shareTextFor(MutashabihatVerseRef verse) => [
  verse.arabic.trim(),
  verse.translation.trim(),
  '— ${verse.surahNameEnglish}, Ayah ${verse.ayah}',
].join('\n\n');

/// One lookalike of the base verse, styled to match [JuzVerseTile]'s
/// reading colors — Arabic in the brand orange with a trailing accent rule,
/// translation in ink — with its own words that diverge from the base
/// picked out (see [HighlightedArabicText]). In quiz mode the text is
/// blurred behind a tap-to-reveal scrim until the reader checks their guess.
class MutashabihatSimilarVerseCard extends StatefulWidget {
  final MutashabihatVerseRef verse;
  final String baseArabic;
  final bool startHidden;

  const MutashabihatSimilarVerseCard({
    super.key,
    required this.verse,
    required this.baseArabic,
    required this.startHidden,
  });

  @override
  State<MutashabihatSimilarVerseCard> createState() =>
      _MutashabihatSimilarVerseCardState();
}

class _MutashabihatSimilarVerseCardState
    extends State<MutashabihatSimilarVerseCard> {
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    _hidden = widget.startHidden;
  }

  @override
  void didUpdateWidget(covariant MutashabihatSimilarVerseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startHidden != widget.startHidden) {
      _hidden = widget.startHidden;
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _shareTextFor(widget.verse)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Verse copied')));
  }

  Future<void> _share() => Share.share(
    _shareTextFor(widget.verse),
    subject: widget.verse.surahNameEnglish,
  );

  @override
  Widget build(BuildContext context) {
    final verse = widget.verse;
    final tokens = similarDiffTokens(widget.baseArabic, verse.arabic);

    return Container(
      margin: EdgeInsets.only(top: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SealNumberBadge(number: verse.ayah, size: 26.w),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        '${verse.surahNameEnglish} · ${verse.verseKey}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<VoidCallback>(
                      tooltip: 'More',
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 17.sp,
                        color: AppColors.textMuted,
                      ),
                      color: AppColors.surfaceLight,
                      onSelected: (action) => action(),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: () => _copy(context),
                          child: Row(
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 18.sp,
                                color: AppColors.inkText,
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                'Copy verse',
                                style: TextStyle(color: AppColors.inkText),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _share,
                          child: Row(
                            children: [
                              Icon(
                                Icons.ios_share_rounded,
                                size: 18.sp,
                                color: AppColors.inkText,
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                'Share verse',
                                style: TextStyle(color: AppColors.inkText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsetsDirectional.only(end: 12.w),
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      end: BorderSide(
                        color: AppColors.emeraldInk.withValues(alpha: 0.45),
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: HighlightedArabicText(
                    tokens: tokens,
                    style: AppTypography.arabicBody.copyWith(
                      fontSize: 19.sp,
                      height: 1.9,
                      color: AppColors.emeraldInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                SelectableText(
                  verse.translation,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 13.5.sp,
                    color: AppColors.inkText,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          if (_hidden)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _hidden = false),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: Container(
                    color: AppColors.surfaceLight.withValues(alpha: 0.6),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34.w,
                          height: 34.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.visibility_outlined,
                            color: AppColors.amberDeep,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Tap to compare',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.amberDeep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../domain/entities/surah_summary.dart';

/// One surah, as a proper elevated card rather than a flat divided row —
/// with the Arabic name actually shown (it was in the data all along, just
/// commented out) and a play button styled with real depth instead of a
/// flat tinted circle.
class SurahListTile extends ConsumerWidget {
  final SurahSummary surah;
  final VoidCallback onTap;
  final VoidCallback onPlayTap;

  const SurahListTile({
    super.key,
    required this.surah,
    required this.onTap,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMakkah = surah.revelationPlace.toLowerCase() == 'makkah';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderWarm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          // The whole card triggers play, not just the small icon — see
          // the button below. `onTap` (reserved for a future reader
          // screen) is intentionally not called here yet.
          onTap: onPlayTap,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _NumberBadge(number: surah.number),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              surah.nameEnglish,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.inkText,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            surah.nameArabic,
                            textDirection: TextDirection.rtl,
                            style: AppTypography.arabicBody.copyWith(
                              fontSize: 18.sp,
                              color: AppColors.quranAccent,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5.h),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${surah.nameTranslation} · ${surah.versesCount} verses',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          _RevelationBadge(isMakkah: isMakkah),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                FavoriteButton(
                  item: FavoriteItem(
                    id: FavoriteItem.buildId(
                      FavoriteContentType.surah,
                      '${surah.number}',
                    ),
                    type: FavoriteContentType.surah,
                    referenceId: '${surah.number}',
                    title: surah.nameEnglish,
                    subtitle:
                        '${surah.nameTranslation} · ${surah.versesCount} verses',
                    route: '/quran',
                    savedAt: DateTime.now(),
                  ),
                ),
                SizedBox(width: 4.w),
                _PlayButton(onTap: onPlayTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The surah number, given real presence — a soft filled badge with a
/// gold ring, rather than just a bare number in an outlined circle.
class _NumberBadge extends StatelessWidget {
  final int number;
  const _NumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.w,
      height: 42.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.quranAccentBg,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Text(
        '$number',
        style: AppTypography.titleMedium.copyWith(
          color: AppColors.quranAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RevelationBadge extends StatelessWidget {
  final bool isMakkah;
  const _RevelationBadge({required this.isMakkah});

  @override
  Widget build(BuildContext context) {
    final color = isMakkah ? AppColors.duasAccent : AppColors.hijriAccent;
    final bg = isMakkah ? AppColors.duasAccentBg : AppColors.hijriAccentBg;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mosque_outlined, size: 9.sp, color: color),
          SizedBox(width: 3.w),
          Text(
            isMakkah ? 'Makkah' : 'Madinah',
            style: AppTypography.caption.copyWith(
              color: color,
              fontSize: 9.5.sp,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tactile, pressable-looking play button — gradient fill and a soft
/// shadow, instead of a flat tinted circle that read as purely decorative.
class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.emeraldInk, AppColors.emeraldInkDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.emeraldInk.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: AppColors.gold,
          size: 20.sp,
        ),
      ),
    );
  }
}

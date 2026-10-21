import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../domain/juz_arabic_names.dart';
import '../widgets/quran_hero.dart';

/// Landing page for the Juz feature: a short intro, then all 30 parts as a
/// grid of tappable cards — each showing the Mushaf icon and the Juz's
/// traditional Arabic name, the way a printed copy labels its parts.
/// Previously this was a bare number grid reached only through a small icon
/// on the Quran screen — now it's a first-class destination of its own,
/// discoverable from Explore.
class JuzHubScreen extends StatelessWidget {
  const JuzHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: QuranHero(
                arabicTitle: 'الأجزاء',
                subtitle: 'Read the Quran in 30 parts',
                stats: [('30', 'Parts'), ('604', 'Pages'), ('1', 'Month')],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 14.h),
                child: Row(
                  children: [
                    Text(
                      'Choose a Juz',
                      style: AppTypography.heroSerif.copyWith(
                        fontSize: 18.sp,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    const Expanded(child: OrnamentDivider()),
                  ],
                ).slideIn(RevealDirection.topStart),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 28.h),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12.h,
                  crossAxisSpacing: 12.w,
                  mainAxisExtent: 78.h,
                ),
                delegate: SliverChildBuilderDelegate(childCount: 30, (
                  context,
                  index,
                ) {
                  final n = index + 1;
                  return _JuzCard(
                    juzNumber: n,
                    arabicName: juzArabicName(n),
                    onTap: () => context.push('/juz/$n'),
                  ).slideInAt(index, columns: 2, distance: 18);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JuzCard extends StatelessWidget {
  final int juzNumber;
  final String arabicName;
  final VoidCallback onTap;

  const _JuzCard({
    required this.juzNumber,
    required this.arabicName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor = AppColors.isDark
        ? AppColors.emeraldInk
        : AppColors.inkText;

    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: onTap,
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.borderWarm),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.heroGradient,
                    ),
                    border: Border.all(color: AppColors.gold, width: 1.4),
                  ),
                  child: Text(
                    '$juzNumber',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldLight,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Juz $juzNumber',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        arabicName,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.arabicBody.copyWith(
                          fontSize: 17.sp,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: nameColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20.sp,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/deen_app_bar.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../domain/juz_arabic_names.dart';

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
      appBar: const DeenAppBar(title: 'Juz', subtitle: 'The 30 parts'),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: const _JuzIntro()),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(childCount: 30, (
                context,
                index,
              ) {
                final juzNumber = index + 1;
                return _JuzCard(
                  juzNumber: juzNumber,
                  arabicName: juzArabicName(juzNumber),
                  onTap: () => context.push('/juz/$juzNumber'),
                ).slideInAt(index, columns: 3, distance: 18);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _JuzIntro extends StatelessWidget {
  const _JuzIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thirty Parts',
                  style: AppTypography.heroSerif.copyWith(
                    fontSize: 22.sp,
                    color: AppColors.inkText,
                  ),
                ).slideIn(RevealDirection.topStart),
                SizedBox(height: 6.h),
                Text(
                  'The Quran divided into 30 equal portions, a traditional '
                  'way to read it steadily over a month. Tap a Juz to start '
                  'reading.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ).slideIn(
                  RevealDirection.start,
                  delay: const Duration(milliseconds: 70),
                ),
                SizedBox(height: 16.h),
                OrnamentDivider(ruleWidth: 40.w).slideIn(
                  RevealDirection.bottomStart,
                  delay: const Duration(milliseconds: 140),
                  distance: 16,
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          Opacity(
            opacity: 0.92,
            child: Image.asset(
              'assets/images/juzz.png',
              width: 68.w,
              height: 68.w,
              fit: BoxFit.contain,
            ),
          ).slideIn(
            RevealDirection.topEnd,
            delay: const Duration(milliseconds: 60),
          ),
        ],
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
    // The Arabic name is the card's headline colour, not just body ink — it
    // takes the brand's orange in Dark (where plain ink would read as a dim
    // grey) and settles to plain black once Light's ink is already black.
    final nameColor = AppColors.isDark
        ? AppColors.emeraldInk
        : AppColors.inkText;

    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.borderWarm),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/juzz.png',
                  width: 42.w,
                  height: 42.w,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  height: 38.h,
                  child: Center(
                    child: Text(
                      arabicName,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.arabicBody.copyWith(
                        fontSize: 14.sp,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: nameColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Juz $juzNumber',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

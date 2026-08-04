import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/deen_app_bar.dart';
import '../../../../shared/widgets/ornament_divider.dart';

/// Landing page for the Juz feature: a short intro, then all 30 parts as a
/// grid of tappable cards. Previously this was a bare number grid reached
/// only through a small icon on the Quran screen — now it's a first-class
/// destination of its own, discoverable from Explore.
class JuzHubScreen extends StatelessWidget {
  const JuzHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: const DeenAppBar(title: 'Juz', subtitle: 'The 30 parts'),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: const _JuzIntro().appear()),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildBuilderDelegate(childCount: 30, (
                context,
                index,
              ) {
                final juzNumber = index + 1;
                return _JuzCard(
                  juzNumber: juzNumber,
                  onTap: () => context.push('/juz/$juzNumber'),
                ).appearStaggered(index);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thirty Parts',
            style: AppTypography.heroSerif.copyWith(
              fontSize: 22.sp,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'The Quran divided into 30 equal portions, a traditional way to '
            'read it steadily over a month. Tap a Juz to start reading.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 16.h),
          OrnamentDivider(ruleWidth: 40.w),
        ],
      ),
    );
  }
}

class _JuzCard extends StatelessWidget {
  final int juzNumber;
  final VoidCallback onTap;

  const _JuzCard({required this.juzNumber, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.quranAccentBg,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '$juzNumber',
                  style: AppTypography.headline.copyWith(
                    fontSize: 15.sp,
                    color: AppColors.quranAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Juz',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

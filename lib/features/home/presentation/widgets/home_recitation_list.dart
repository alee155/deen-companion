import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/domain/entities/surah_summary.dart';

const List<String> _thumbnails = [
  'assets/images/slider_1.jpg',
  'assets/images/slider_2.jpg',
  'assets/images/slider_3.jpg',
  'assets/images/slider_4.jpg',
  'assets/images/slider_5.jpg',
];

/// Horizontal row of recitation cards for Home's "Recitations" section.
/// Takes real [SurahSummary]s (see `home_recitations_provider.dart`) rather
/// than any placeholder data — the duration badge shown in early mockups
/// isn't real data the app has, so this shows verse count instead.
class HomeRecitationList extends StatelessWidget {
  final List<SurahSummary> surahs;
  final ValueChanged<SurahSummary> onTap;

  const HomeRecitationList({
    super.key,
    required this.surahs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: surahs.length,
        itemBuilder: (context, index) {
          final surah = surahs[index];
          return _RecitationCard(
            surah: surah,
            image: _thumbnails[index % _thumbnails.length],
            isLast: index == surahs.length - 1,
            onTap: () => onTap(surah),
          ).slideInAt(index, columns: 2, distance: 20);
        },
      ),
    );
  }
}

class _RecitationCard extends StatelessWidget {
  final SurahSummary surah;
  final String image;
  final bool isLast;
  final VoidCallback onTap;

  const _RecitationCard({
    required this.surah,
    required this.image,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: Container(
        height: 130.h,
        width: 260.w,
        margin: EdgeInsets.only(right: isLast ? 0 : 12.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset(image, fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10.h,
              left: 10.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${surah.versesCount} verses',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14.w,
              right: 60.w,
              bottom: 14.h,
              child: Text(
                surah.nameEnglish,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              right: 12.w,
              bottom: 10.h,
              child: Container(
                height: 40.h,
                width: 40.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 22.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

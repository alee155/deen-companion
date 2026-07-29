import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/hadith.dart';

class HadithDetailScreen extends ConsumerStatefulWidget {
  final Hadith hadith;
  const HadithDetailScreen({super.key, required this.hadith});

  @override
  ConsumerState<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends ConsumerState<HadithDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Logged once per visit, after the first frame — not on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hadith = widget.hadith;
      ref
          .read(recentActivityNotifierProvider.notifier)
          .logActivity(
            RecentActivityItem(
              id: RecentActivityItem.buildId(
                RecentActivityType.hadith,
                hadith.id,
              ),
              type: RecentActivityType.hadith,
              referenceId: hadith.id,
              title: '${hadith.collectionName} · Hadith ${hadith.hadithNumber}',
              subtitle: hadith.english,
              route: '/hadith/read/${hadith.collection}',
              viewedAt: DateTime.now(),
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hadith = widget.hadith;
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: Text(hadith.collectionName),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Center(
              child: FavoriteButton(
                size: 22,
                item: FavoriteItem(
                  id: FavoriteItem.buildId(
                    FavoriteContentType.hadith,
                    hadith.id,
                  ),
                  type: FavoriteContentType.hadith,
                  referenceId: hadith.id,
                  title:
                      '${hadith.collectionName} · Hadith ${hadith.hadithNumber}',
                  subtitle: hadith.english,
                  route: '/hadith/read/${hadith.collection}',
                  savedAt: DateTime.now(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.hadithAccentBg,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Hadith ${hadith.hadithNumber}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.hadithAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.quranAccentBg,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    hadith.grade,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.emeraldInk,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              hadith.arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: AppTypography.arabicBody.copyWith(
                fontSize: 20.sp,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 20.h),
            Divider(color: AppColors.borderWarm),
            SizedBox(height: 20.h),
            Text(
              hadith.english,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.inkText),
            ),
          ],
        ).appear(),
      ),
    );
  }
}

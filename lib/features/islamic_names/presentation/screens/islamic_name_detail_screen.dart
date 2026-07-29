import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/islamic_name.dart';

class IslamicNameDetailScreen extends StatelessWidget {
  final IslamicName name;
  final VoidCallback onShuffle;

  const IslamicNameDetailScreen({
    super.key,
    required this.name,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final isMale = name.gender == 'male';
    final accent = isMale ? AppColors.boyAccent : AppColors.girlAccent;
    final accentBg = isMale ? AppColors.boyAccentBg : AppColors.girlAccentBg;
    final rootLetters =
        name.root?.split(' ').where((s) => s.isNotEmpty).toList() ??
        const <String>[];

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    isMale ? 'Boy name' : 'Girl name',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  name.name,
                  style: TextStyle(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  name.arabic,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 24.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEANING',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  name.meaning,
                  style: TextStyle(fontSize: 15.sp, color: AppColors.inkText),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.parchment,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        name.origin,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'ROOT LETTERS',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: rootLetters.map((letter) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 6.w),
                width: 48.w,
                height: 48.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.duasAccentBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  letter,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 20.sp,
                    color: AppColors.duasAccent,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 20.h),
          if (name.note.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_stories_outlined, color: accent, size: 18.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      name.note,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.inkText,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle),
              label: const Text('Another random name'),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/asma_name.dart';

class AsmaNameCard extends StatelessWidget {
  final AsmaName name;
  const AsmaNameCard({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Subtle watermark star behind the Arabic — same motif used elsewhere.
              Opacity(
                opacity: 0.08,
                child: Icon(
                  Icons.auto_awesome,
                  size: 160.sp,
                  color: AppColors.gold,
                ),
              ),
              Column(
                children: [
                  Text(
                    name.arabic,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 58.sp,
                      color: AppColors.inkText,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    name.transliteration,
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: AppColors.gold,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            name.english,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Text(
              name.meaning,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/asma_name.dart';

class AsmaNameTile extends StatelessWidget {
  final AsmaName name;
  final VoidCallback onTap;

  const AsmaNameTile({super.key, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62.w,
            height: 62.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.goldLight, Colors.white],
              ),
              border: Border.all(
                color: AppColors.gold.withOpacity(0.6),
                width: 1.4,
              ),
            ),
            child: Text(
              name.arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.inkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            name.transliteration,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

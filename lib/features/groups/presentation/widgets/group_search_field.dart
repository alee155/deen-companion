import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

class GroupSearchField extends StatelessWidget {
  final TextEditingController controller;
  const GroupSearchField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return Container(
          height: 52.h,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Row(
            children: [
              SizedBox(width: 16.w),
              Icon(
                Icons.search_rounded,
                size: 21.sp,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  cursorColor: AppColors.worshipAccent,
                  style: TextStyle(fontSize: 14.sp, color: AppColors.inkText),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Search your groups…',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
              if (hasText)
                Pressable(
                  onTap: controller.clear,
                  scale: AppMotion.pressScaleSmall,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Icon(
                      Icons.close_rounded,
                      size: 19.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else
                SizedBox(width: 14.w),
            ],
          ),
        );
      },
    );
  }
}

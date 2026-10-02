import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../splash/presentation/splash_branding.dart';

/// The About block: app identity, then Privacy Policy, Terms & Conditions and
/// the installed version, as one bordered card in the app's style.
class SettingsAboutCard extends StatelessWidget {
  final String version;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

  const SettingsAboutCard({
    super.key,
    required this.version,
    required this.onPrivacy,
    required this.onTerms,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.borderWarm, width: 1.2),
                  ),
                  child: Image.asset(
                    SplashBranding.logoAsset,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Made for the Ummah 🤍',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderWarm),
          _Row(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            trailing: Icons.north_east_rounded,
            onTap: onPrivacy,
          ),
          Divider(height: 1, color: AppColors.borderWarm),
          _Row(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            trailing: Icons.north_east_rounded,
            onTap: onTerms,
          ),
          Divider(height: 1, color: AppColors.borderWarm),
          _Row(
            icon: Icons.info_outline_rounded,
            title: 'Version',
            value: version,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final IconData? trailing;
  final String? value;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.title,
    this.trailing,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: AppColors.worshipAccentBg,
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(icon, size: 18.sp, color: AppColors.worshipAccent),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.worshipAccent,
              ),
            ),
          if (trailing != null)
            Icon(trailing, size: 17.sp, color: AppColors.emeraldInk),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22.r),
      child: row,
    );
  }
}

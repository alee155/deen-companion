import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}

/// Generic reader for long-form legal text (Privacy Policy, Terms &
/// Conditions). Kept in-app rather than opening a browser, since the
/// hosted policy page's URL is set per-deployment (see
/// AppConstants) and may not exist yet in every build.
class LegalTextScreen extends StatelessWidget {
  final String title;
  final String updatedLabel;
  final List<LegalSection> sections;

  const LegalTextScreen({
    super.key,
    required this.title,
    required this.updatedLabel,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          Text(
            updatedLabel,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 20.h),
          for (final section in sections) ...[
            Text(
              section.heading,
              style: AppTypography.headline.copyWith(
                color: AppColors.inkText,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              section.body,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ],
      ),
    );
  }
}

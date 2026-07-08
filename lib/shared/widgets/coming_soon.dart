import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

void showComingSoonSnackbar(BuildContext context, String featureName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$featureName is coming soon.'),
      backgroundColor: AppColors.emeraldInk,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

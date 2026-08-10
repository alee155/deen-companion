import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';

class DeenApp extends ConsumerWidget {
  const DeenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final choice = ref.watch(themeModeNotifierProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final lightTheme = AppTheme.light();
        final darkTheme = AppTheme.dark();
        final isDark = choice == AppThemeChoice.dark;
        AppColors.applyBrightness(isDark ? Brightness.dark : Brightness.light);
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: AppColors.surfaceLight,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
        );
        return MaterialApp.router(
          key: ValueKey(choice),
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: choice.themeMode,
          routerConfig: router,
        );
      },
    );
  }
}

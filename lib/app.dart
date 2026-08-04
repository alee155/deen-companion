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
        // Built inside the builder, not outside: the text styles in the theme
        // are sized with ScreenUtil's `.sp`, which is only initialised once
        // ScreenUtilInit has run.
        //
        // Building a ThemeData installs its palette into AppColors, so the
        // last one built would otherwise win — hence the explicit
        // applyBrightness afterwards, before any screen reads a colour.
        final lightTheme = AppTheme.light();
        final darkTheme = AppTheme.dark();
        final isDark = choice == AppThemeChoice.dark;
        AppColors.applyBrightness(isDark ? Brightness.dark : Brightness.light);

        // Screens without an app bar (Home, Qibla, the splash) don't get an
        // overlay style from AppBarTheme, so set it once here — otherwise the
        // status bar icons stay dark-on-dark after switching to Dark.
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
          // Keying on the choice forces a full rebuild of the tree when the
          // user switches appearance. Screens read colours from the static
          // AppColors accessors rather than from an InheritedWidget, so a
          // theme change is not something they would otherwise be rebuilt
          // for; this makes the switch apply everywhere, immediately.
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

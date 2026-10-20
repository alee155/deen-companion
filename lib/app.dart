import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/constants/app_constants.dart';
import 'core/motion/motion.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/theme/presentation/providers/theme_period_provider.dart';
import 'features/theme/presentation/widgets/theme_crossfade.dart';

class DeenApp extends ConsumerWidget {
  const DeenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final variant = ref.watch(activeThemeVariantProvider);
    final motionLevel = ref.watch(motionLevelProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        // One theme for whichever look is active (a fixed appearance or a
        // prayer period). It installs the matching palette as it builds.
        final theme = AppTheme.forVariant(variant);
        final isDark = variant.isDark;
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
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: theme,
          themeMode: ThemeMode.light,
          // ThemeCrossfade owns the transition. Material's own 200 ms theme
          // lerp would blend Theme-driven colours while the static palette
          // jumps, so the two halves of the screen would change out of step.
          themeAnimationDuration: Duration.zero,
          routerConfig: router,
          // Not keyed on the theme: a look change rebuilds in place (state and
          // navigation survive) and fades, see [ThemeCrossfade].
          builder: (context, child) => MotionScope(
            level: motionLevel,
            child: ThemeCrossfade(
              variant: variant,
              child: child ?? const SizedBox(),
            ),
          ),
        );
      },
    );
  }
}

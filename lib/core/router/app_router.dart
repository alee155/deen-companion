import 'package:deen_companion/features/audio_player/presentation/screens/audio_player_screen.dart';
import 'package:deen_companion/features/explore/presentation/screens/all_features_screen.dart';
import 'package:deen_companion/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:deen_companion/features/profile/presentation/screens/profile_screen.dart';
import 'package:deen_companion/features/profile/presentation/screens/settings_screen.dart';
import 'package:deen_companion/features/recent_activity/presentation/screens/recent_activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/prayer_times/presentation/screens/prayer_times_screen.dart';
import '../../features/quran/presentation/screens/juz_detail_screen.dart';
import '../../features/quran/presentation/screens/juz_list_screen.dart';
import '../../features/quran/presentation/screens/mushaf_page_screen.dart';
import '../../features/quran/presentation/screens/quran_search_screen.dart';
import '../../features/quran/presentation/screens/surah_list_screen.dart';

import 'app_routes.dart';
import 'app_shell.dart';
import '../../features/hadith/domain/entities/hadith.dart';
import '../../features/hadith/presentation/screens/hadith_detail_screen.dart';
import '../../features/hadith/presentation/screens/hadith_search_screen.dart';
import '../../features/hadith/presentation/screens/hadith_hub_screen.dart';
import '../../features/duas/domain/entities/dua_category.dart';
import '../../features/duas/presentation/screens/dua_category_screen.dart';
import '../../features/duas/presentation/screens/dua_search_screen.dart';
import '../../features/duas/presentation/screens/duas_hub_screen.dart';
import '../../features/islamic_calendar/presentation/screens/date_converter_screen.dart';
import '../../features/islamic_calendar/presentation/screens/islamic_calendar_hub_screen.dart';
import '../../features/islamic_calendar/presentation/screens/islamic_months_screen.dart';
import '../../features/zakat/presentation/screens/zakat_agriculture_screen.dart';
import '../../features/zakat/presentation/screens/zakat_calculator_screen.dart';
import '../../features/zakat/presentation/screens/zakat_hub_screen.dart';
import '../../features/zakat/presentation/screens/zakat_info_screen.dart';
import '../../features/qibla/presentation/screens/qibla_screen.dart';
import '../../features/asma_ul_husna/presentation/screens/asma_hub_screen.dart';
import '../../features/asma_ul_husna/presentation/screens/asma_search_screen.dart';
import '../../features/mutashabihat/presentation/screens/mutashabihat_hub_screen.dart';
import '../../features/islamic_names/presentation/screens/islamic_names_hub_screen.dart';
import '../../features/hadith/presentation/screens/hadith_reading_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen(this.label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // Top-level — no bottom nav (unchanged group, plus new additions below)
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => const AudioPlayerScreen(),
      ),
      GoRoute(
        path: '/quran',
        builder: (context, state) => const SurahListScreen(),
      ), // moved out of shell
      GoRoute(
        path: '/prayer-times',
        builder: (context, state) => const PrayerTimesScreen(),
      ), // moved out of shell
      GoRoute(
        path: '/hadith',
        builder: (context, state) => const HadithHubScreen(),
      ), // moved out of shell
      GoRoute(
        path: '/hadith/read/:collectionKey',
        builder: (context, state) => HadithReadingScreen(
          collectionKey: state.pathParameters['collectionKey']!,
        ),
      ),
      GoRoute(
        path: '/hadith/search',
        builder: (context, state) => const HadithSearchScreen(),
      ),
      GoRoute(
        path: '/hadith/detail',
        builder: (context, state) =>
            HadithDetailScreen(hadith: state.extra as Hadith),
      ),
      GoRoute(
        path: '/quran/search',
        builder: (context, state) => const QuranSearchScreen(),
      ),
      GoRoute(
        path: '/quran/juz',
        builder: (context, state) => const JuzListScreen(),
      ),
      GoRoute(
        path: '/quran/juz/:number',
        builder: (context, state) => JuzDetailScreen(
          juzNumber: int.parse(state.pathParameters['number']!),
        ),
      ),
      GoRoute(
        path: '/quran/page/:number',
        builder: (context, state) => MushafPageScreen(
          initialPage: int.parse(state.pathParameters['number']!),
        ),
      ),
      GoRoute(
        path: '/explore',
        builder: (context, state) => const AllFeaturesScreen(),
      ),
      GoRoute(
        path: '/duas',
        builder: (context, state) => const DuasHubScreen(),
      ),
      GoRoute(
        path: '/duas/search',
        builder: (context, state) => const DuaSearchScreen(),
      ),
      GoRoute(
        path: '/duas/category/:id',
        builder: (context, state) =>
            DuaCategoryScreen(category: state.extra as DuaCategory),
      ),
      GoRoute(
        path: '/islamic-calendar',
        builder: (context, state) => const IslamicCalendarHubScreen(),
      ),
      GoRoute(
        path: '/islamic-calendar/converter',
        builder: (context, state) => const DateConverterScreen(),
      ),
      GoRoute(
        path: '/islamic-calendar/months',
        builder: (context, state) => const IslamicMonthsScreen(),
      ),
      GoRoute(
        path: '/zakat',
        builder: (context, state) => const ZakatHubScreen(),
      ),
      GoRoute(
        path: '/zakat/calculator',
        builder: (context, state) => const ZakatCalculatorScreen(),
      ),
      GoRoute(
        path: '/zakat/agriculture',
        builder: (context, state) => const ZakatAgricultureScreen(),
      ),
      GoRoute(
        path: '/zakat/info',
        builder: (context, state) => const ZakatInfoScreen(),
      ),
      GoRoute(path: '/qibla', builder: (context, state) => const QiblaScreen()),
      GoRoute(
        path: '/asma-ul-husna',
        builder: (context, state) => const AsmaHubScreen(),
      ),
      GoRoute(
        path: '/asma-ul-husna/search',
        builder: (context, state) => const AsmaSearchScreen(),
      ),
      GoRoute(
        path: '/islamic-names',
        builder: (context, state) => const IslamicNamesHubScreen(),
      ),
      GoRoute(
        path: '/mutashabihat',
        builder: (context, state) => const MutashabihatHubScreen(),
      ),
      // Bottom-tab destinations live under a single StatefulShellRoute so the
      // bottom navigation bar (built once, inside AppShell) never disappears
      // when switching tabs, and each tab keeps its own independent back
      // stack + scroll position via IndexedStack.
      //
      // NOTE: these paths used to also exist as separate top-level GoRoutes
      // above (outside the shell). That duplication was the actual cause of
      // the bottom nav bar vanishing: GoRouter matches routes in declaration
      // order, so the top-level copy — which rendered without AppShell —
      // was winning the match instead of the shell's branch route.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recent-activity',
                builder: (context, state) => const RecentActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: '/profile/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

import 'package:deen_companion/features/audio_player/presentation/screens/audio_player_screen.dart';
import 'package:deen_companion/features/explore/presentation/screens/all_features_screen.dart';
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
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    routes: [
      // ── Top-level routes — no bottom nav, full-screen drill-downs ──
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
        path: AppRoutes.duas,
        builder: (context, state) => const DuasHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.duasSearch,
        builder: (context, state) => const DuaSearchScreen(),
      ),
      GoRoute(
        path: '/duas/category/:id',
        builder: (context, state) =>
            DuaCategoryScreen(category: state.extra as DuaCategory),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => const AudioPlayerScreen(),
      ),
      GoRoute(
        path: AppRoutes.hadithSearch,
        builder: (context, state) => const HadithSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.hadithDetail,
        builder: (context, state) =>
            HadithDetailScreen(hadith: state.extra as Hadith),
      ),
      GoRoute(
        path: '/explore',
        builder: (context, state) => const AllFeaturesScreen(),
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
        builder: (context, state) {
          final number = int.parse(state.pathParameters['number']!);
          return JuzDetailScreen(juzNumber: number);
        },
      ),
      GoRoute(
        path: '/quran/page/:number',
        builder: (context, state) {
          final number = int.parse(state.pathParameters['number']!);
          return MushafPageScreen(initialPage: number);
        },
      ),

      // ── Tab roots — always wrapped in the shell (bottom nav) ──
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.quran,
            builder: (context, state) => const SurahListScreen(),
          ),
          GoRoute(
            path: AppRoutes.prayerTimes,
            builder: (context, state) => const PrayerTimesScreen(),
          ),
          GoRoute(
            path: AppRoutes.learn,
            builder: (context, state) => const HadithHubScreen(),
          ),
        ],
      ),
    ],
  );
});

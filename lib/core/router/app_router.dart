import 'package:deen_companion/features/audio_player/presentation/screens/audio_player_screen.dart';
import 'package:deen_companion/features/explore/presentation/screens/all_features_screen.dart';
import 'package:deen_companion/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:deen_companion/features/groups/presentation/screens/create_group_screen.dart';
import 'package:deen_companion/features/groups/presentation/screens/group_streak_screen.dart';
import 'package:deen_companion/features/groups/presentation/screens/groups_screen.dart';
import 'package:deen_companion/features/profile/presentation/screens/profile_screen.dart';
import 'package:deen_companion/features/profile/presentation/screens/settings_screen.dart';
import 'package:deen_companion/features/recent_activity/presentation/screens/recent_activity_screen.dart';
import 'package:flutter/foundation.dart';
import '../motion/motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/prayer_times/presentation/screens/prayer_times_screen.dart';
import '../../features/quran/presentation/screens/juz_hub_screen.dart';
import '../../features/quran/presentation/screens/juz_reading_screen.dart';
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
import '../../features/zakat/presentation/screens/zakat_hub_screen.dart';
import '../../features/qibla/presentation/screens/qibla_screen.dart';
import '../../features/asma_ul_husna/presentation/screens/asma_hub_screen.dart';
import '../../features/asma_ul_husna/presentation/screens/asma_search_screen.dart';
import '../../features/mutashabihat/presentation/screens/mutashabihat_hub_screen.dart';
import '../../features/islamic_names/presentation/screens/islamic_names_hub_screen.dart';
import '../../features/hadith/presentation/screens/hadith_reading_screen.dart';
import '../../features/daily_content/presentation/screens/daily_content_screen.dart';
import '../../features/daily_content/presentation/screens/notifications_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/prayer_dnd/presentation/screens/prayer_dnd_screen.dart';
import '../../features/prayer_reminders/presentation/screens/reminders_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,
    routes: [
      // Top-level — no bottom nav (unchanged group, plus new additions below)
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => AppTransitionPage(
          context: context,
          state: state,
          kind: AppTransitionKind.fadeThrough,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => AppTransitionPage(
          context: context,
          state: state,
          kind: AppTransitionKind.fadeThrough,
          child: const WelcomeScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => AppTransitionPage(
          context: context,
          state: state,
          kind: AppTransitionKind.fadeThrough,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => AppTransitionPage(
          context: context,
          state: state,
          kind: AppTransitionKind.fadeThrough,
          child: const SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) =>
            OtpScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => AppTransitionPage(
          context: context,
          state: state,
          kind: AppTransitionKind.fadeThrough,
          child: const ForgotPasswordScreen(),
        ),
      ),
      // Group flow screens. Declared at the top level (outside the shell) so
      // the bottom navigation bar isn't shown on them; `/groups` itself stays
      // a shell tab. Push these with `context.push`, not `go`.
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/groups/:groupId/streak',
        builder: (context, state) =>
            GroupStreakScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/daily-content',
        builder: (context, state) =>
            DailyContentScreen(notificationId: state.uri.queryParameters['id']),
      ),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => const RemindersScreen(),
      ),
      GoRoute(
        path: '/prayer-dnd',
        builder: (context, state) => const PrayerDndScreen(),
      ),
      GoRoute(
        path: '/recent-activity',
        builder: (context, state) => const RecentActivityScreen(),
      ),
      GoRoute(
        path: '/player',
        pageBuilder: (context, state) => AppTransitionPage(
          context: context,
          state: state,
          kind: AppTransitionKind.slideUp,
          child: const AudioPlayerScreen(),
        ),
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
      GoRoute(path: '/juz', builder: (context, state) => const JuzHubScreen()),
      GoRoute(
        path: '/juz/:number',
        builder: (context, state) => JuzReadingScreen(
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
        builder: (context, state) => const ZakatHubScreen(initialTab: 0),
      ),
      GoRoute(
        path: '/zakat/agriculture',
        builder: (context, state) => const ZakatHubScreen(initialTab: 1),
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
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            AnimatedBranchContainer(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
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
                path: '/groups',
                builder: (context, state) => const GroupsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

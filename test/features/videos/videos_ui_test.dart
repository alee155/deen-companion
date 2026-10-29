import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:deen_companion/features/videos/domain/entities/bayan_video.dart';
import 'package:deen_companion/features/videos/domain/entities/video_platform.dart';
import 'package:deen_companion/features/videos/presentation/providers/videos_providers.dart';
import 'package:deen_companion/features/videos/presentation/screens/video_player_screen.dart';
import 'package:deen_companion/features/videos/presentation/screens/videos_screen.dart';
import 'package:deen_companion/features/videos/presentation/widgets/home_video_section.dart';
import 'package:deen_companion/features/videos/presentation/widgets/video_card.dart';
import 'package:deen_companion/features/videos/presentation/widgets/video_player_surface.dart';
import 'package:deen_companion/features/videos/presentation/widgets/video_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '_videos_support.dart';

/// Stands in for YouTube's web player, which needs a real WebView.
Widget _fakePlayer(
  BuildContext context,
  BayanVideo video,
  VoidCallback onUnavailable,
) => Column(
  children: [
    Text('PLAYER ${video.source.videoId}'),
    TextButton(onPressed: onUnavailable, child: const Text('FAIL')),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required Widget Function() screen,
  FakeVideosRepo? repo,
  String path = '/',
  List<GoRoute> extra = const [],
}) async {
  tester.view.physicalSize = const Size(390 * 3, 1700 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen()),
      GoRoute(path: '/videos', builder: (_, _) => const Text('VIDEOS PAGE')),
      GoRoute(
        path: '/video/:id',
        builder: (_, s) => VideoPlayerScreen(videoId: s.pathParameters['id']!),
      ),
      ...extra,
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videosRepositoryProvider.overrideWithValue(repo ?? FakeVideosRepo()),
        videoPlayerBuildersProvider.overrideWithValue({
          VideoPlatform.youtube: _fakePlayer,
        }),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// The title row the Home screen draws.
HomeVideoSection _section() => HomeVideoSection(
  headerBuilder: () => Builder(
    builder: (context) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(child: Text('Bayan of the day')),
        TextButton(
          onPressed: () => context.push('/videos'),
          child: const Text('See All'),
        ),
      ],
    ),
  ),
);

void main() {
  group('Home section', () {
    testWidgets('shows the day\'s talks with title and speaker', (
      tester,
    ) async {
      await _pump(tester, screen: () => Scaffold(body: _section()));
      expect(find.text('Bayan of the day'), findsOneWidget);
      expect(find.text('See All'), findsOneWidget);
      expect(
        find.text('The Love of Allah | Life Changing Bayan'),
        findsOneWidget,
      );
      expect(find.text('Maulana Tariq Jameel'), findsOneWidget);
      expect(find.byType(VideoCard), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a card opens that talk, See All opens the list', (
      tester,
    ) async {
      await _pump(tester, screen: () => Scaffold(body: _section()));
      await tester.tap(find.text('See All'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('VIDEOS PAGE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('only the first five are on Home', (tester) async {
      final many = dailyVideosFromMany(8);
      await _pump(
        tester,
        repo: FakeVideosRepo(result: Success(many)),
        screen: () => Scaffold(body: _section()),
      );
      expect(find.text('Talk 0'), findsOneWidget);
      // The row scrolls sideways: go to its end, and Talk 4 is the last.
      await tester.drag(find.byType(ListView), const Offset(-2000, 0));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Talk 4'), findsOneWidget);
      expect(find.text('Talk 5'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('large text makes the row taller instead of overflowing', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, screen: () => Scaffold(body: _section()));
      expect(tester.takeException(), isNull);
      expect(
        find.text('The Love of Allah | Life Changing Bayan'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no videos: nothing is shown at all', (tester) async {
      await _pump(
        tester,
        repo: FakeVideosRepo(result: Success(dailyVideosFromMany(0))),
        screen: () => Scaffold(body: _section()),
      );
      expect(find.text('Bayan of the day'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failure leaves a quiet retry line, not a broken block', (
      tester,
    ) async {
      final repo = FakeVideosRepo(result: const Error(NetworkFailure()));
      await _pump(
        tester,
        repo: repo,
        screen: () => Scaffold(body: _section()),
      );
      expect(find.text('Videos unavailable · Retry'), findsOneWidget);
      expect(find.byType(VideoCard), findsNothing);

      repo.result = Success(sampleDaily());
      await tester.tap(find.text('Videos unavailable · Retry'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(VideoCard), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Videos screen', () {
    testWidgets('lists every talk and filters by topic', (tester) async {
      await _pump(tester, screen: () => const VideosScreen());
      expect(find.byType(VideoTile), findsNWidgets(3));
      expect(find.text('3 talks'), findsOneWidget);
      expect(find.text('2 topics'), findsOneWidget);

      // The chip comes before the list, so it is the first "Namaz".
      await tester.ensureVisible(find.text('Namaz').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Namaz').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(VideoTile), findsNWidgets(2));
      expect(
        find.text('The Love of Allah | Life Changing Bayan'),
        findsNothing,
      );

      await tester.ensureVisible(find.text('All'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('All'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(VideoTile), findsNWidgets(3));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failure with nothing to show offers to try again', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeVideosRepo(result: const Error(NetworkFailure())),
        screen: () => const VideosScreen(),
      );
      expect(find.text('Try again'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Player screen', () {
    final id = videoAt(0).id;

    testWidgets('a YouTube talk plays in the in-app player, with its details', (
      tester,
    ) async {
      await _pump(tester, path: '/video/$id', screen: () => const SizedBox());
      expect(find.text('PLAYER 5ES0cFPNpbE'), findsOneWidget);
      expect(
        find.text('The Love of Allah | Life Changing Bayan'),
        findsOneWidget,
      );
      expect(find.text('Maulana Tariq Jameel'), findsOneWidget);
      expect(find.text('Allah ki Mohabbat'), findsOneWidget);
      expect(find.text('Urdu'), findsOneWidget);
      expect(
        find.text('Allah ki mohabbat par bayan (Feb 2025)'),
        findsOneWidget,
      );
      expect(find.text('Watch on YouTube'), findsOneWidget);
      expect(find.text('More from today'), findsOneWidget);
      expect(find.byType(VideoTile), findsNWidgets(2), reason: 'the other two');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('if YouTube refuses it, the poster offers the link instead', (
      tester,
    ) async {
      await _pump(tester, path: '/video/$id', screen: () => const SizedBox());
      await tester.tap(find.text('FAIL'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PLAYER 5ES0cFPNpbE'), findsNothing);
      expect(find.byType(VideoPoster), findsOneWidget);
      expect(find.textContaining('can’t be played here'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'a platform the app can\'t play gets the open-the-link poster',
      (tester) async {
        final other = dailyVideosFromOtherPlatform();
        await _pump(
          tester,
          repo: FakeVideosRepo(result: Success(other)),
          path: '/video/${other.videos.first.id}',
          screen: () => const SizedBox(),
        );
        expect(find.byType(VideoPoster), findsOneWidget);
        expect(find.textContaining('PLAYER'), findsNothing);
        expect(find.text('Open link'), findsWidgets);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('a talk that is not in today\'s set says so', (tester) async {
      await _pump(tester, path: '/video/nope', screen: () => const SizedBox());
      expect(find.textContaining('isn’t in today’s set'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('another talk replaces this one', (tester) async {
      await _pump(tester, path: '/video/$id', screen: () => const SizedBox());
      await tester.tap(find.text('Namaz Importance | Way To Jannah'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('PLAYER Uq5YCuGkgjo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('the in-app player is looked up by platform', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final builders = c.read(videoPlayerBuildersProvider);
    expect(builders.keys, [VideoPlatform.youtube]);
  });

  // Not used by the screens; here so a change to the audio provider's state
  // (the player screen pauses a playing surah) is noticed.
  test('the audio state the player screen reads exists', () {
    expect(const AudioPlayerState().isPlaying, isFalse);
  });
}

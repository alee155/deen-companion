import 'package:deen_companion/features/audio_player/presentation/widgets/mihrab_artwork.dart';
import 'package:deen_companion/features/audio_player/presentation/widgets/now_playing_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_player_support.dart';

/// Every callback the view can fire, recorded in order.
class _Calls {
  final log = <String>[];
  double? speed;
  Duration? sleep;
  Duration? seek;
}

Widget _view(
  _Calls c, {
  bool playing = true,
  bool looping = false,
  double speed = 1.0,
  Duration? sleepRemaining,
}) => NowPlayingView(
  titleArabic: 'البقرة',
  titleEnglish: 'Al-Baqarah',
  reciterName: 'Mishary Rashid Alafasy',
  surahNumber: 2,
  favoriteItem: favoriteFixture(),
  isPlaying: playing,
  isLooping: looping,
  speed: speed,
  position: const Duration(minutes: 23, seconds: 41),
  duration: const Duration(hours: 2, minutes: 4, seconds: 10),
  sleepTimerRemaining: sleepRemaining,
  onPlayPause: () => c.log.add('playPause'),
  onNext: () => c.log.add('next'),
  onPrevious: () => c.log.add('previous'),
  onBack10: () => c.log.add('back10'),
  onForward10: () => c.log.add('forward10'),
  onSeek: (d) => c.seek = d,
  onToggleLoop: () => c.log.add('loop'),
  onSetSpeed: (s) => c.speed = s,
  onSetSleepTimer: (d) => c.sleep = d,
  onCancelSleepTimer: () => c.log.add('cancelSleep'),
  onStop: () => c.log.add('stop'),
  onMinimize: () => c.log.add('minimize'),
);

Future<void> _settle(WidgetTester tester) async {
  // The artwork's pattern turns forever while playing, so never settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('names the surah, its reciter and its number', (tester) async {
    await pumpPlayer(tester, _view(_Calls()));

    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('Mishary Rashid Alafasy'), findsOneWidget);
    expect(find.text('البقرة'), findsOneWidget); // on the artwork
    expect(find.text('٢'), findsOneWidget); // surah 2 in Arabic numerals
    expect(find.text('23:41'), findsOneWidget);
    expect(find.text('-1:40:29'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  group('transport', () {
    testWidgets('pause while playing, play while paused', (tester) async {
      final c = _Calls();
      await pumpPlayer(tester, _view(c));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      expect(c.log, ['playPause']);

      await pumpPlayer(tester, _view(c, playing: false));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('previous, next and the 10-second jumps', (tester) async {
      final c = _Calls();
      await pumpPlayer(tester, _view(c));

      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.tap(find.byIcon(Icons.replay_10_rounded));
      await tester.tap(find.byIcon(Icons.forward_10_rounded));
      await tester.tap(find.byIcon(Icons.skip_next_rounded));

      expect(c.log, ['previous', 'back10', 'forward10', 'next']);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('options', () {
    testWidgets('repeat toggles and says when it is on', (tester) async {
      final c = _Calls();
      await pumpPlayer(tester, _view(c));
      expect(find.text('Repeat'), findsOneWidget);
      await tester.tap(find.text('Repeat'));
      expect(c.log, ['loop']);

      await pumpPlayer(tester, _view(c, looping: true));
      expect(find.text('Repeat on'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('speed opens a list and applies the choice', (tester) async {
      final c = _Calls();
      await pumpPlayer(tester, _view(c));
      expect(find.text('1×'), findsOneWidget);

      await tester.tap(find.text('1×'));
      await _settle(tester);
      expect(find.text('Playback speed'), findsOneWidget);
      expect(find.text('Normal (1×)'), findsOneWidget);

      await tester.tap(find.text('1.25×'));
      await _settle(tester);

      expect(c.speed, 1.25);
      expect(find.text('Playback speed'), findsNothing); // the sheet closed

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the current speed is shown on the button', (tester) async {
      await pumpPlayer(tester, _view(_Calls(), speed: 1.5));
      expect(find.text('1.5×'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sleep timer offers lengths and applies one', (tester) async {
      final c = _Calls();
      await pumpPlayer(tester, _view(c));

      await tester.tap(find.text('Sleep'));
      await _settle(tester);
      expect(find.text('Sleep timer'), findsOneWidget);
      expect(find.textContaining('Turn off'), findsNothing);

      await tester.tap(find.text('30 minutes'));
      await _settle(tester);

      expect(c.sleep, const Duration(minutes: 30));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a running timer counts down on the button and can be '
        'turned off', (tester) async {
      final c = _Calls();
      await pumpPlayer(
        tester,
        _view(c, sleepRemaining: const Duration(minutes: 29, seconds: 12)),
      );
      expect(find.text('29:12'), findsOneWidget);

      await tester.tap(find.text('29:12'));
      await _settle(tester);
      await tester.tap(find.text('Turn off (29:12 left)'));
      await _settle(tester);

      expect(c.log, ['cancelSleep']);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('title row', () {
    testWidgets('the heart adds the surah to favourites', (tester) async {
      final favorites = await pumpPlayer(tester, _view(_Calls()));

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();

      expect(favorites.toggled.map((f) => f.id), ['surah:2']);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the menu stops playback', (tester) async {
      final c = _Calls();
      await pumpPlayer(tester, _view(c));

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await _settle(tester);
      await tester.tap(find.text('Stop playback'));
      await _settle(tester);

      expect(c.log, ['stop']);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('minimising', () {
    testWidgets('the handle closes the player', (tester) async {
      final c = _Calls();
      await pumpPlayer(tester, _view(c));

      await tester.tapAt(const Offset(195, 22));
      expect(c.log, ['minimize']);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a downward fling closes it too', (tester) async {
      final c = _Calls();
      await pumpPlayer(tester, _view(c));

      await tester.fling(
        find.byType(MihrabArtwork),
        const Offset(0, 300),
        1500,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(c.log, ['minimize']);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a slow drag or an upward fling does not', (tester) async {
      final c = _Calls();
      await pumpPlayer(tester, _view(c));

      await tester.fling(
        find.byType(MihrabArtwork),
        const Offset(0, -300),
        1500,
      );
      await tester.drag(find.byType(MihrabArtwork), const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 500));

      expect(c.log, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('artwork', () {
    double scale(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    testWidgets('full size while playing, settled when paused', (tester) async {
      await pumpPlayer(tester, _view(_Calls()));
      expect(scale(tester), 1.0);

      await pumpPlayer(tester, _view(_Calls(), playing: false));
      expect(scale(tester), 0.9);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('fits', () {
    for (final (name, size) in [
      ('a small iPhone', const Size(375, 667)),
      ('an Android phone', const Size(360, 800)),
      ('a large phone', const Size(430, 932)),
    ]) {
      testWidgets(name, (tester) async {
        await pumpPlayer(
          tester,
          _view(_Calls(), looping: true, speed: 1.25),
          size: size,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('with larger text', (tester) async {
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpPlayer(
        tester,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 667),
            textScaler: TextScaler.linear(1.3),
          ),
          child: _view(_Calls()),
        ),
        size: const Size(375, 667),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

import 'package:deen_companion/features/audio_player/presentation/widgets/mini_player_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_player_support.dart';

void main() {
  Future<List<String>> pump(
    WidgetTester tester, {
    bool playing = true,
    double progress = 0.34,
  }) async {
    final calls = <String>[];
    await pumpPlayer(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: MiniPlayerBar(
          title: 'Al-Baqarah',
          titleArabic: 'البقرة',
          subtitle: 'Mishary Rashid Alafasy',
          isPlaying: playing,
          progress: progress,
          onTap: () => calls.add('open'),
          onPlayPause: () => calls.add('playPause'),
          onNext: () => calls.add('next'),
          onClose: () => calls.add('close'),
        ),
      ),
    );
    return calls;
  }

  testWidgets('names the surah, the reciter and shows the artwork', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('Mishary Rashid Alafasy'), findsOneWidget);
    expect(find.text('البقرة'), findsOneWidget);
  });

  testWidgets('shows pause while playing and play while paused', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await pump(tester, playing: false);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
  });

  testWidgets('each button does its own job', (tester) async {
    final calls = await pump(tester);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.tap(find.byIcon(Icons.close_rounded));

    expect(calls, ['playPause', 'next', 'close']);
  });

  testWidgets('tapping the bar opens the full player', (tester) async {
    final calls = await pump(tester);

    await tester.tap(find.text('Al-Baqarah'));

    expect(calls, ['open']);
  });

  testWidgets('is a compact strip, not a block', (tester) async {
    await pump(tester);

    final box = tester.getRect(find.byType(MiniPlayerBar));
    expect(box.height, lessThan(100));
    expect(box.height, greaterThan(50));
  });

  testWidgets('progress outside 0..1 is kept inside the bar', (tester) async {
    await pump(tester, progress: 1.7);
    expect(tester.takeException(), isNull);
    await pump(tester, progress: -0.4);
    expect(tester.takeException(), isNull);
  });
}

import 'package:deen_companion/features/audio_player/presentation/widgets/player_scrubber.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '_player_support.dart';

void main() {
  test('formatPlayerTime shows minutes, and hours only past an hour', () {
    expect(formatPlayerTime(Duration.zero), '0:00');
    expect(formatPlayerTime(const Duration(seconds: 65)), '1:05');
    expect(formatPlayerTime(const Duration(minutes: 59, seconds: 9)), '59:09');
    expect(
      formatPlayerTime(const Duration(hours: 2, minutes: 4, seconds: 10)),
      '2:04:10',
    );
  });

  group('PlayerScrubber', () {
    const total = Duration(minutes: 10);

    Future<List<Duration>> pump(
      WidgetTester tester, {
      Duration position = const Duration(minutes: 2),
      Duration duration = total,
    }) async {
      final seeks = <Duration>[];
      await pumpPlayer(
        tester,
        Padding(
          padding: const EdgeInsets.all(20),
          child: PlayerScrubber(
            position: position,
            duration: duration,
            onSeek: seeks.add,
          ),
        ),
      );
      return seeks;
    }

    testWidgets('shows the elapsed time and what is left, with a minus', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('2:00'), findsOneWidget);
      expect(find.text('-8:00'), findsOneWidget);
    });

    testWidgets('dragging follows the finger and seeks once, on release', (
      tester,
    ) async {
      final seeks = await pump(tester);
      final box = tester.getRect(find.byType(PlayerScrubber));

      final gesture = await tester.startGesture(
        Offset(box.left + 4, box.top + 15),
      );
      await gesture.moveTo(Offset(box.center.dx, box.top + 15));
      await tester.pump();

      // Midway: five minutes in, five to go, and nothing seeked yet.
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('-5:00'), findsOneWidget);
      expect(seeks, isEmpty);

      await gesture.up();
      await tester.pump();

      expect(seeks, hasLength(1));
      expect(seeks.single.inSeconds, closeTo(300, 3));
    });

    testWidgets('tapping the line seeks to that point', (tester) async {
      final seeks = await pump(tester);
      final box = tester.getRect(find.byType(PlayerScrubber));

      await tester.tapAt(Offset(box.left + box.width * 0.75, box.top + 15));
      await tester.pump();

      expect(seeks, hasLength(1));
      expect(seeks.single.inSeconds, closeTo(450, 4));
    });

    testWidgets('does nothing before the length is known', (tester) async {
      final seeks = await pump(
        tester,
        position: Duration.zero,
        duration: Duration.zero,
      );
      final box = tester.getRect(find.byType(PlayerScrubber));

      await tester.tapAt(Offset(box.center.dx, box.top + 15));
      await tester.pump();

      expect(seeks, isEmpty);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('-0:00'), findsOneWidget);
    });

    testWidgets('screen readers can step it 10 seconds at a time', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final seeks = await pump(tester);

      final node = tester.getSemantics(
        find.bySemanticsLabel('Playback position'),
      );
      expect(node.value, '2:00 of 10:00');
      expect(node.increasedValue, '2:10');
      expect(node.decreasedValue, '1:50');

      tester.semantics.performAction(
        find.semantics.byLabel('Playback position'),
        SemanticsAction.increase,
      );
      tester.semantics.performAction(
        find.semantics.byLabel('Playback position'),
        SemanticsAction.decrease,
      );

      expect(seeks, [
        const Duration(minutes: 2, seconds: 10),
        const Duration(minutes: 1, seconds: 50),
      ]);
      handle.dispose();
    });

    testWidgets('stepping never leaves the track', (tester) async {
      final handle = tester.ensureSemantics();
      final seeks = await pump(
        tester,
        position: const Duration(seconds: 4),
        duration: const Duration(seconds: 8),
      );

      tester.semantics.performAction(
        find.semantics.byLabel('Playback position'),
        SemanticsAction.decrease,
      );
      tester.semantics.performAction(
        find.semantics.byLabel('Playback position'),
        SemanticsAction.increase,
      );

      expect(seeks, [Duration.zero, const Duration(seconds: 8)]);
      handle.dispose();
    });
  });
}

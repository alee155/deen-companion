import 'package:deen_companion/features/audio_player/domain/audio_track.dart';
import 'package:deen_companion/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:deen_companion/features/audio_player/presentation/providers/surah_navigation.dart';
import 'package:deen_companion/features/quran/domain/entities/surah_summary.dart';
import 'package:deen_companion/features/quran/presentation/providers/quran_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A player with no audio engine behind it: it holds a track and records what
/// it is asked to play.
class _FakePlayer extends AudioPlayerNotifier {
  _FakePlayer(this._initial);
  final AudioTrack? _initial;
  final played = <AudioTrack>[];

  @override
  AudioPlayerState build() => AudioPlayerState(track: _initial);

  @override
  Future<void> playTrack(AudioTrack track) async => played.add(track);
}

class _FakeSurahs extends SurahListNotifier {
  _FakeSurahs(this._list);
  final List<SurahSummary> _list;

  @override
  Stream<List<SurahSummary>> build() => Stream.value(_list);
}

SurahSummary _surah(int n) => SurahSummary(
  number: n,
  nameArabic: 'ar$n',
  nameEnglish: 'Surah $n',
  nameTranslation: 't$n',
  revelationPlace: 'Meccan',
  versesCount: n,
  bismillahPre: true,
  exampleAudioUrl: 'https://example.test/$n.mp3',
);

AudioTrack _track(int n) => AudioTrack(
  id: 'surah-$n',
  titleEnglish: 'Surah $n',
  titleArabic: 'ar$n',
  reciterName: 'Reciter',
  url: 'https://example.test/$n.mp3',
);

void main() {
  /// Runs [action] inside a widget tree and returns what the player was told
  /// to play.
  Future<List<AudioTrack>> run(
    WidgetTester tester, {
    required AudioTrack? current,
    required int delta,
    List<SurahSummary>? surahs,
  }) async {
    final player = _FakePlayer(current);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerNotifierProvider.overrideWith(() => player),
          surahListNotifierProvider.overrideWith(
            () =>
                _FakeSurahs(surahs ?? [for (var i = 1; i <= 5; i++) _surah(i)]),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              // Let the surah list load before it is read.
              ref.watch(surahListNotifierProvider);
              return TextButton(
                onPressed: () => playAdjacentSurah(ref, delta: delta),
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pump();
    return player.played;
  }

  testWidgets('next plays the following surah, keeping the reciter', (
    tester,
  ) async {
    final played = await run(tester, current: _track(2), delta: 1);

    expect(played, hasLength(1));
    expect(played.single.id, 'surah-3');
    expect(played.single.titleEnglish, 'Surah 3');
    expect(played.single.url, 'https://example.test/3.mp3');
    expect(played.single.reciterName, 'Reciter');
  });

  testWidgets('previous plays the one before', (tester) async {
    final played = await run(tester, current: _track(3), delta: -1);
    expect(played.single.id, 'surah-2');
  });

  testWidgets('stops at either end of the list', (tester) async {
    expect(await run(tester, current: _track(1), delta: -1), isEmpty);
    expect(await run(tester, current: _track(5), delta: 1), isEmpty);
  });

  testWidgets('does nothing with nothing playing', (tester) async {
    expect(await run(tester, current: null, delta: 1), isEmpty);
  });

  testWidgets('does nothing for a track that is not a surah', (tester) async {
    final odd = AudioTrack(
      id: 'dua-1',
      titleEnglish: 'x',
      titleArabic: 'x',
      reciterName: 'r',
      url: 'u',
    );
    expect(await run(tester, current: odd, delta: 1), isEmpty);
  });
}

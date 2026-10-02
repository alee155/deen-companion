import 'package:deen_companion/features/audio_player/domain/audio_track.dart';
import 'package:deen_companion/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// AudioPlayerNotifier itself constructs a just_audio AudioPlayer (platform
// channels) in build(), so only the pure state class is unit-testable.
void main() {
  const track = AudioTrack(
    id: 'surah-1',
    titleEnglish: 'Al-Fatihah',
    titleArabic: 'الفاتحة',
    reciterName: 'Alafasy',
    url: 'https://a/1.mp3',
  );

  group('AudioPlayerState', () {
    test('defaults represent an idle player', () {
      const s = AudioPlayerState();
      expect(s.hasTrack, isFalse);
      expect(s.isPlaying, isFalse);
      expect(s.position, Duration.zero);
      expect(s.duration, Duration.zero);
      expect(s.isLooping, isFalse);
      expect(s.hasSleepTimer, isFalse);
    });

    test('hasTrack / hasSleepTimer reflect fields', () {
      const s = AudioPlayerState(
        track: track,
        sleepTimerRemaining: Duration(minutes: 5),
      );
      expect(s.hasTrack, isTrue);
      expect(s.hasSleepTimer, isTrue);
    });

    test('a zero-length sleep timer still counts as a timer', () {
      const s = AudioPlayerState(sleepTimerRemaining: Duration.zero);
      expect(s.hasSleepTimer, isTrue);
    });

    test('copyWith changes only the given fields', () {
      const s = AudioPlayerState(
        track: track,
        isPlaying: true,
        position: Duration(seconds: 3),
        duration: Duration(seconds: 30),
        isLooping: true,
        sleepTimerRemaining: Duration(minutes: 1),
      );
      final c = s.copyWith(position: const Duration(seconds: 9));

      expect(c.position, const Duration(seconds: 9));
      expect(c.track, track);
      expect(c.isPlaying, isTrue);
      expect(c.duration, const Duration(seconds: 30));
      expect(c.isLooping, isTrue);
      expect(c.sleepTimerRemaining, const Duration(minutes: 1));
    });

    test('clearTrack removes the track even when a new one is passed', () {
      const s = AudioPlayerState(track: track);
      expect(s.copyWith(clearTrack: true).track, isNull);
      expect(s.copyWith(clearTrack: true, track: track).track, isNull);
    });

    test('clearSleepTimer removes the timer; omitting keeps it', () {
      const s = AudioPlayerState(sleepTimerRemaining: Duration(minutes: 2));
      expect(s.copyWith(clearSleepTimer: true).sleepTimerRemaining, isNull);
      expect(
        s.copyWith(isPlaying: true).sleepTimerRemaining,
        const Duration(minutes: 2),
      );
    });

    test('copyWith cannot null out a field via null argument', () {
      const s = AudioPlayerState(track: track);
      expect(s.copyWith(track: null).track, track);
    });
  });
}

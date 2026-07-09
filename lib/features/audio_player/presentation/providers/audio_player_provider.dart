import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../domain/audio_track.dart';

class AudioPlayerState {
  final AudioTrack? track;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isLooping;

  const AudioPlayerState({
    this.track,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isLooping = false,
  });

  bool get hasTrack => track != null;

  AudioPlayerState copyWith({
    AudioTrack? track,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isLooping,
    bool clearTrack = false,
  }) {
    return AudioPlayerState(
      track: clearTrack ? null : (track ?? this.track),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isLooping: isLooping ?? this.isLooping,
    );
  }
}

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  late final AudioPlayer _player;

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();

    _player.playerStateStream.listen((s) {
      state = state.copyWith(isPlaying: s.playing);
    });
    _player.positionStream.listen((p) {
      state = state.copyWith(position: p);
    });
    _player.durationStream.listen((d) {
      if (d != null) state = state.copyWith(duration: d);
    });

    ref.onDispose(() => _player.dispose());
    return const AudioPlayerState();
  }

  Future<void> toggleLoop() async {
    final looping = !state.isLooping;
    await _player.setLoopMode(looping ? LoopMode.one : LoopMode.off);
    state = state.copyWith(isLooping: looping);
  }

  Future<void> playTrack(AudioTrack track) async {
    if (state.track?.id == track.id) {
      await togglePlayPause();
      return;
    }

    final wasLooping = state.isLooping;
    state = AudioPlayerState(track: track, isLooping: wasLooping);
    await _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(track.url),
        tag: MediaItem(
          id: track.id,
          title: track.titleEnglish,
          artist: track.reciterName,
        ),
      ),
    );
    await _player.setLoopMode(wasLooping ? LoopMode.one : LoopMode.off);
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> skipForward() =>
      _player.seek(state.position + const Duration(seconds: 10));
  Future<void> skipBackward() =>
      _player.seek(state.position - const Duration(seconds: 10));

  Future<void> stop() async {
    await _player.stop();
    state = const AudioPlayerState();
  }
}

final audioPlayerNotifierProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
      AudioPlayerNotifier.new,
    );

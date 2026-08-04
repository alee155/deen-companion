import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/audio_track.dart';

class AudioPlayerState {
  final AudioTrack? track;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isLooping;

  /// Time remaining on the sleep timer, ticking down once per second.
  /// Null means no timer is running.
  final Duration? sleepTimerRemaining;

  const AudioPlayerState({
    this.track,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isLooping = false,
    this.sleepTimerRemaining,
  });

  bool get hasTrack => track != null;
  bool get hasSleepTimer => sleepTimerRemaining != null;

  AudioPlayerState copyWith({
    AudioTrack? track,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isLooping,
    Duration? sleepTimerRemaining,
    bool clearTrack = false,
    bool clearSleepTimer = false,
  }) {
    return AudioPlayerState(
      track: clearTrack ? null : (track ?? this.track),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isLooping: isLooping ?? this.isLooping,
      sleepTimerRemaining: clearSleepTimer
          ? null
          : (sleepTimerRemaining ?? this.sleepTimerRemaining),
    );
  }
}

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  late final AudioPlayer _player;
  Timer? _sleepTimerTicker;

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();
    _player.playerStateStream.listen(
      (s) => state = state.copyWith(isPlaying: s.playing),
    );
    _player.positionStream.listen((p) {
      // Some streamed sources report a too-short initial duration
      // estimate that durationStream never revises on its own — if
      // position ever exceeds what we think the total is, the estimate
      // was simply wrong, so correct it live instead of leaving the
      // progress bar frozen at an impossible >100% position.
      final correctedDuration = p > state.duration ? p : state.duration;
      state = state.copyWith(position: p, duration: correctedDuration);
    });
    _player.processingStateStream.listen((s) {
      // Duration estimates for some streamed sources firm up once
      // buffering finishes — re-read the player's own (by-then more
      // authoritative) duration getter as a second correction point.
      if (s == ProcessingState.ready) {
        final real = _player.duration;
        if (real != null && real > state.duration) {
          state = state.copyWith(duration: real);
        }
      }
    });
    _player.durationStream.listen((d) {
      // Only grows the known duration, never shrinks it. This stream
      // re-emits the same stale, too-short estimate periodically for some
      // sources — without this guard, every re-emission was undoing the
      // upward correction positionStream had just made, which is why the
      // total kept snapping back to the wrong value.
      if (d != null && d > state.duration) state = state.copyWith(duration: d);
    });
    ref.onDispose(() {
      _sleepTimerTicker?.cancel();
      _player.dispose();
    });
    return const AudioPlayerState();
  }

  Future<void> toggleLoop() async {
    final looping = !state.isLooping;
    await _player.setLoopMode(looping ? LoopMode.one : LoopMode.off);
    state = state.copyWith(isLooping: looping);
  }

  Future<void> playTrack(AudioTrack track) async {
    // Background playback is initialised once in bootstrap(), before this
    // player exists — nothing to set up per track.
    if (state.track?.id == track.id) {
      await togglePlayPause();
      return;
    }

    final wasLooping = state.isLooping;
    // A new track starting is exactly when a leftover sleep timer from
    // the previous track should NOT silently keep running against it.
    _sleepTimerTicker?.cancel();
    state = AudioPlayerState(track: track, isLooping: wasLooping);
    try {
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
    } catch (error, stackTrace) {
      // Expected if the user navigated away and stop() raced with this
      // still-loading source — the platform connection gets aborted
      // underneath us. Logged, not rethrown: stop() or the next
      // playTrack() call already leaves the player in a sane state.
      AppLogger.e(
        'AudioPlayer: load/play failed or was interrupted',
        error,
        stackTrace,
      );
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// Jumps playback to an absolute position — what dragging the progress
  /// slider actually needs, as opposed to the relative nudge [skipForward]
  /// and [skipBackward] do.
  Future<void> seek(Duration position) async {
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > state.duration ? state.duration : position);
    await _player.seek(clamped);
    // Reflected immediately rather than waiting on positionStream, so a
    // dropped slider thumb doesn't visibly snap back before the stream
    // catches up.
    state = state.copyWith(position: clamped);
  }

  Future<void> skipForward() =>
      _player.seek(state.position + const Duration(seconds: 10));
  Future<void> skipBackward() =>
      _player.seek(state.position - const Duration(seconds: 10));

  /// Starts (or replaces) a sleep timer: playback pauses automatically
  /// once [duration] elapses. Ticks [AudioPlayerState.sleepTimerRemaining]
  /// down once a second so the UI can show a countdown.
  void setSleepTimer(Duration duration) {
    _sleepTimerTicker?.cancel();
    var remaining = duration;
    state = state.copyWith(sleepTimerRemaining: remaining);

    _sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        timer.cancel();
        _player.pause();
        state = state.copyWith(clearSleepTimer: true);
      } else {
        state = state.copyWith(sleepTimerRemaining: remaining);
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimerTicker?.cancel();
    _sleepTimerTicker = null;
    state = state.copyWith(clearSleepTimer: true);
  }

  Future<void> stop() async {
    _sleepTimerTicker?.cancel();
    _sleepTimerTicker = null;
    try {
      await _player.stop();
    } catch (error, stackTrace) {
      AppLogger.e('AudioPlayer: stop failed', error, stackTrace);
    }
    state = const AudioPlayerState();
  }
}

final audioPlayerNotifierProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
      AudioPlayerNotifier.new,
    );

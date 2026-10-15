import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../snaps/domain/entities/snap_draft.dart';
import '../../../snaps/presentation/providers/snap_providers.dart';
import '../../domain/prayer_log.dart';
import '../../domain/prayer_log_failure.dart';
import '../prayer_labels.dart';
import 'prayer_logs_providers.dart';

enum PrayerLogStep { capture, crop, confirm }

@immutable
class PrayerLogComposerState {
  final PrayerLogStep step;

  /// The capture, prepared for cropping.
  final Uint8List? source;

  /// The cropped image shown on the confirm step.
  final Uint8List? cropped;

  /// Compressed upload, ready once [isProcessing] clears on the confirm step.
  final PreparedImage? prepared;
  final bool isProcessing;
  final bool isSubmitting;
  final String? errorMessage;

  /// Set once the server has the log (a fresh one, or the one that already
  /// existed).
  final PrayerLog? logged;
  final bool wasAlreadyLogged;

  const PrayerLogComposerState({
    this.step = PrayerLogStep.capture,
    this.source,
    this.cropped,
    this.prepared,
    this.isProcessing = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.logged,
    this.wasAlreadyLogged = false,
  });

  bool get canSubmit => prepared != null && !isProcessing && !isSubmitting;

  PrayerLogComposerState copyWith({
    PrayerLogStep? step,
    Uint8List? source,
    Uint8List? cropped,
    PreparedImage? prepared,
    bool clearImages = false,
    bool? isProcessing,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    PrayerLog? logged,
    bool? wasAlreadyLogged,
  }) => PrayerLogComposerState(
    step: step ?? this.step,
    source: clearImages ? null : (source ?? this.source),
    cropped: clearImages ? null : (cropped ?? this.cropped),
    prepared: clearImages ? null : (prepared ?? this.prepared),
    isProcessing: isProcessing ?? this.isProcessing,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    logged: logged ?? this.logged,
    wasAlreadyLogged: wasAlreadyLogged ?? this.wasAlreadyLogged,
  );
}

/// Capture → crop → confirm → upload for logging the open prayer. The server
/// chooses the prayer; this only supplies the photo.
class PrayerLogComposerController
    extends AutoDisposeNotifier<PrayerLogComposerState> {
  final List<String> _tempPaths = [];

  @override
  PrayerLogComposerState build() {
    // Captured now: providers can't be read once disposal has started.
    final processor = ref.read(snapImageProcessorProvider);
    ref.onDispose(() => processor.cleanUp(_tempPaths));
    return const PrayerLogComposerState();
  }

  static const _tag = 'LOG FLOW';

  Future<void> onCaptured(String path) async {
    FlowLog.log(_tag, 'STEP 1 - PHOTO CAPTURED -> preparing it for cropping');
    _tempPaths.add(path);
    state = state.copyWith(isProcessing: true, clearError: true);
    final result = await ref
        .read(snapImageProcessorProvider)
        .prepareForEditing(path);
    switch (result) {
      case Success(:final data):
        FlowLog.log(_tag, 'STEP 2 - READY TO CROP (${data.length} bytes)');
        state = state.copyWith(
          step: PrayerLogStep.crop,
          source: data,
          isProcessing: false,
        );
      case Error(:final failure):
        state = state.copyWith(
          isProcessing: false,
          errorMessage: failure.message,
        );
    }
  }

  /// Cropped: show the confirm step straight away and compress meanwhile.
  Future<void> onCropped(Uint8List bytes) async {
    FlowLog.log(
      _tag,
      'STEP 3 - CROPPED (${bytes.length} bytes) -> compressing for upload',
    );
    state = state.copyWith(
      step: PrayerLogStep.confirm,
      cropped: bytes,
      isProcessing: true,
      clearError: true,
    );
    final result = await ref
        .read(snapImageProcessorProvider)
        .compressForUpload(bytes);
    // The user may have gone back while compressing.
    if (state.cropped != bytes) return;
    switch (result) {
      case Success(:final data):
        FlowLog.log(
          _tag,
          'STEP 4 - COMPRESSED: ${data.originalBytes} -> ${data.compressedBytes} bytes '
          '(limit 5 MB). Ready to log.',
        );
        _tempPaths.add(data.path);
        state = state.copyWith(prepared: data, isProcessing: false);
      case Error(:final failure):
        state = state.copyWith(
          isProcessing: false,
          errorMessage: failure.message,
        );
    }
  }

  void retake() {
    FlowLog.log(_tag, 'RETAKE -> starting over from the camera');
    state = const PrayerLogComposerState();
  }

  void recrop() => state = state.copyWith(
    step: PrayerLogStep.crop,
    isProcessing: false,
    clearError: true,
  );

  /// Uploads the photo. True when the prayer is now logged — including when
  /// the server says it already was, since the user's goal is met either way.
  Future<bool> submit() async {
    if (!state.canSubmit) {
      FlowLog.log(_tag, 'SUBMIT IGNORED: the photo is not ready yet');
      return false;
    }
    FlowLog.log(_tag, 'STEP 5 - USER TAPPED LOG -> uploading');
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await ref
        .read(prayerLogActionsProvider)
        .log(state.prepared!.path);
    switch (result) {
      case Success(:final data):
        state = state.copyWith(isSubmitting: false, logged: data);
        return true;
      case Error(:final failure):
        if (failure is PrayerLogFailure &&
            failure.code == PrayerLogErrorCode.alreadyLogged) {
          FlowLog.log(
            _tag,
            'ALREADY LOGGED -> treated as done, showing the existing log',
          );
          state = state.copyWith(
            isSubmitting: false,
            logged: failure.existingLog,
            wasAlreadyLogged: true,
          );
          return true;
        }
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: prayerLogErrorMessage(failure),
        );
        return false;
    }
  }
}

final prayerLogComposerProvider =
    NotifierProvider.autoDispose<
      PrayerLogComposerController,
      PrayerLogComposerState
    >(PrayerLogComposerController.new);

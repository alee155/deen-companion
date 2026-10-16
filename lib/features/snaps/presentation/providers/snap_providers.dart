import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/permissions/camera_permission_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../data/camera/camera_plugin_service.dart';
import '../../data/camera/camera_session.dart';
import '../../data/flutter_snap_image_processor.dart';
import '../../data/prayer_log_snap_repository.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import '../../domain/entities/snap_draft.dart';
import '../../domain/repositories/snap_image_processor.dart';
import '../../domain/repositories/snap_repository.dart';

final cameraServiceProvider = Provider<CameraService>(
  (ref) => const CameraPluginService(),
);

final snapImageProcessorProvider = Provider<SnapImageProcessor>(
  (ref) => const FlutterSnapImageProcessor(),
);

/// Sending a snap logs the open prayer through `POST /prayers/logs`.
final snapRepositoryProvider = Provider<SnapRepository>(
  (ref) => PrayerLogSnapRepository(log: ref.read(prayerLogActionsProvider).log),
);

// ---------------------------------------------------------------------------
// Camera
// ---------------------------------------------------------------------------

@immutable
class CameraUiState {
  /// Null when the camera isn't open (opening, closed, or [problem] set).
  final CameraSession? session;
  final CameraProblem? problem;
  final SnapLens lens;
  final SnapFlash flash;
  final double zoom;
  final bool isOpening;
  final bool isCapturing;

  const CameraUiState({
    this.session,
    this.problem,
    this.lens = SnapLens.back,
    this.flash = SnapFlash.off,
    this.zoom = 1,
    this.isOpening = true,
    this.isCapturing = false,
  });

  bool get isReady => session != null && problem == null;

  CameraUiState copyWith({
    CameraSession? session,
    bool clearSession = false,
    CameraProblem? problem,
    bool clearProblem = false,
    SnapLens? lens,
    SnapFlash? flash,
    double? zoom,
    bool? isOpening,
    bool? isCapturing,
  }) => CameraUiState(
    session: clearSession ? null : (session ?? this.session),
    problem: clearProblem ? null : (problem ?? this.problem),
    lens: lens ?? this.lens,
    flash: flash ?? this.flash,
    zoom: zoom ?? this.zoom,
    isOpening: isOpening ?? this.isOpening,
    isCapturing: isCapturing ?? this.isCapturing,
  );
}

/// Owns the camera's lifecycle and the capture controls. The screen only
/// calls these methods and renders [CameraUiState].
class SnapCameraController extends AutoDisposeNotifier<CameraUiState> {
  bool _disposed = false;

  @override
  CameraUiState build() {
    ref.onDispose(() {
      _disposed = true;
      final s = state.session;
      if (s != null) s.dispose();
    });
    Future.microtask(() => _open(SnapLens.back));
    return const CameraUiState();
  }

  Future<void> _open(SnapLens lens) async {
    state = state.copyWith(isOpening: true, clearProblem: true, lens: lens);
    try {
      final session = await ref.read(cameraServiceProvider).open(lens);
      if (_disposed) {
        await session.dispose();
        return;
      }
      state = state.copyWith(
        session: session,
        lens: session.lens,
        flash: SnapFlash.off,
        zoom: 1,
        isOpening: false,
      );
    } on CameraOpenException catch (e) {
      if (_disposed) return;
      var problem = e.problem;
      // The plugin can't tell "denied once" from "don't ask again". When the
      // OS will no longer prompt, steer the user to Settings instead.
      if (problem == CameraProblem.denied &&
          await ref
              .read(cameraPermissionServiceProvider)
              .isPermanentlyDenied()) {
        problem = CameraProblem.deniedForever;
      }
      if (_disposed) return;
      state = state.copyWith(
        clearSession: true,
        problem: problem,
        isOpening: false,
      );
    } catch (e, st) {
      AppLogger.e('Camera: unexpected failure opening the camera', e, st);
      if (_disposed) return;
      state = state.copyWith(
        clearSession: true,
        problem: CameraProblem.unavailable,
        isOpening: false,
      );
    }
  }

  /// Retry after a problem (e.g. the user just granted permission).
  Future<void> retry() => _open(state.lens);

  /// Release the camera while the app is backgrounded.
  Future<void> pause() async {
    final s = state.session;
    if (s == null) return;
    state = state.copyWith(clearSession: true);
    await s.dispose();
  }

  Future<void> resume() async {
    if (state.session == null && state.problem == null && !state.isOpening) {
      await _open(state.lens);
    }
  }

  Future<void> switchLens() async {
    if (state.isOpening || state.isCapturing) return;
    final old = state.session;
    final next = state.lens == SnapLens.back ? SnapLens.front : SnapLens.back;
    state = state.copyWith(clearSession: true);
    await old?.dispose();
    await _open(next);
  }

  Future<void> cycleFlash() async {
    final s = state.session;
    if (s == null || !s.hasFlash) return;
    final next = state.flash.next;
    await s.setFlash(next);
    state = state.copyWith(flash: next);
  }

  Future<void> setZoom(double zoom) async {
    final s = state.session;
    if (s == null) return;
    final z = zoom.clamp(s.minZoom, s.maxZoom);
    if ((z - state.zoom).abs() < 0.01) return;
    state = state.copyWith(zoom: z);
    await s.setZoom(z);
  }

  Future<void> focusAt(Offset normalized) async =>
      state.session?.focusAt(normalized);

  /// Takes the photo and returns its path, or null if it failed.
  Future<String?> capture() async {
    final s = state.session;
    if (s == null || state.isCapturing) return null;
    state = state.copyWith(isCapturing: true);
    try {
      return await s.takePicture();
    } catch (_) {
      return null;
    } finally {
      if (!_disposed) state = state.copyWith(isCapturing: false);
    }
  }
}

final snapCameraControllerProvider =
    NotifierProvider.autoDispose<SnapCameraController, CameraUiState>(
      SnapCameraController.new,
    );

// ---------------------------------------------------------------------------
// Composer (capture → crop → preview → recipients, then send)
// ---------------------------------------------------------------------------

enum SnapStep { capture, crop, edit, recipients }

@immutable
class SnapComposerState {
  final SnapStep step;

  /// The capture, prepared for cropping.
  final Uint8List? source;

  /// The cropped image shown in the preview step.
  final Uint8List? cropped;
  final int viewSeconds;
  final String caption;

  /// Compressed upload, set once the user moves on to recipients.
  final PreparedImage? prepared;
  final bool isProcessing;
  final bool isSending;
  final String? errorMessage;

  const SnapComposerState({
    this.step = SnapStep.capture,
    this.source,
    this.cropped,
    this.viewSeconds = SnapViewTimer.defaultSeconds,
    this.caption = '',
    this.prepared,
    this.isProcessing = false,
    this.isSending = false,
    this.errorMessage,
  });

  SnapComposerState copyWith({
    SnapStep? step,
    Uint8List? source,
    Uint8List? cropped,
    bool clearImages = false,
    int? viewSeconds,
    String? caption,
    PreparedImage? prepared,
    bool clearPrepared = false,
    bool? isProcessing,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) => SnapComposerState(
    step: step ?? this.step,
    source: clearImages ? null : (source ?? this.source),
    cropped: clearImages ? null : (cropped ?? this.cropped),
    viewSeconds: viewSeconds ?? this.viewSeconds,
    caption: caption ?? this.caption,
    prepared: clearPrepared ? null : (prepared ?? this.prepared),
    isProcessing: isProcessing ?? this.isProcessing,
    isSending: isSending ?? this.isSending,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Drives the snap flow for one group. All image work and sending go through
/// repositories; the UI only reacts to [SnapComposerState].
class SnapComposerController
    extends AutoDisposeFamilyNotifier<SnapComposerState, String> {
  final List<String> _tempPaths = [];

  @override
  SnapComposerState build(String groupId) {
    // Captured now: providers can't be read once disposal has started.
    final processor = ref.read(snapImageProcessorProvider);
    ref.onDispose(() => processor.cleanUp(_tempPaths));
    return const SnapComposerState();
  }

  /// A photo was taken: prepare it and move to cropping.
  Future<void> onCaptured(String path) async {
    _tempPaths.add(path);
    state = state.copyWith(isProcessing: true, clearError: true);
    final result = await ref
        .read(snapImageProcessorProvider)
        .prepareForEditing(path);
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          step: SnapStep.crop,
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

  void onCropped(Uint8List bytes) {
    state = state.copyWith(
      step: SnapStep.edit,
      cropped: bytes,
      clearPrepared: true,
      clearError: true,
    );
  }

  /// Discard everything and go back to the camera.
  void retake() {
    state = SnapComposerState(viewSeconds: state.viewSeconds);
  }

  void recrop() => state = state.copyWith(step: SnapStep.crop);

  void setTimer(int seconds) => state = state.copyWith(viewSeconds: seconds);

  void setCaption(String value) => state = state.copyWith(caption: value);

  /// Compress the final image and show the recipients.
  Future<void> continueToRecipients() async {
    final cropped = state.cropped;
    if (cropped == null || state.isProcessing) return;
    if (state.prepared != null) {
      state = state.copyWith(step: SnapStep.recipients, clearError: true);
      return;
    }
    state = state.copyWith(isProcessing: true, clearError: true);
    final result = await ref
        .read(snapImageProcessorProvider)
        .compressForUpload(cropped);
    switch (result) {
      case Success(:final data):
        _tempPaths.add(data.path);
        state = state.copyWith(
          step: SnapStep.recipients,
          prepared: data,
          isProcessing: false,
        );
      case Error(:final failure):
        state = state.copyWith(
          isProcessing: false,
          errorMessage: failure.message,
        );
    }
  }

  void backToEdit() =>
      state = state.copyWith(step: SnapStep.edit, clearError: true);

  /// Sends to [recipientIds] — always the whole group (the UI doesn't allow
  /// choosing). Returns true on success; the screen then closes the flow.
  Future<bool> send(List<String> recipientIds) async {
    final prepared = state.prepared;
    if (prepared == null || state.isSending) return false;
    FlowLog.log(
      'SEND SNAP',
      'USER TAPPED SEND: photo ${prepared.compressedBytes} bytes, '
          '${recipientIds.length} recipients',
    );
    state = state.copyWith(isSending: true, clearError: true);
    final caption = state.caption.trim();
    final result = await ref
        .read(snapRepositoryProvider)
        .sendSnap(
          SnapDraft(
            groupId: arg,
            imagePath: prepared.path,
            viewSeconds: state.viewSeconds,
            caption: caption.isEmpty ? null : caption,
            recipientIds: recipientIds,
          ),
        );
    switch (result) {
      case Success(:final data):
        FlowLog.log('SEND SNAP', 'SEND FINISHED OK (snap id ${data.id})');
        state = state.copyWith(isSending: false);
        return true;
      case Error(:final failure):
        FlowLog.error('SEND SNAP', 'SEND FAILED', failure.message);
        state = state.copyWith(isSending: false, errorMessage: failure.message);
        return false;
    }
  }
}

final snapComposerProvider = NotifierProvider.autoDispose
    .family<SnapComposerController, SnapComposerState, String>(
      SnapComposerController.new,
    );

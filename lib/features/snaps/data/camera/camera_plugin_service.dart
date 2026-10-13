import 'dart:ui' show Offset;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, PlatformException;
import 'package:flutter/widgets.dart';
import '../../../../core/utils/logger.dart';
import 'camera_session.dart';

/// [CameraService] backed by the `camera` plugin.
class CameraPluginService implements CameraService {
  const CameraPluginService();

  @override
  Future<CameraSession> open(SnapLens lens) async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      AppLogger.e('Camera: availableCameras failed (${e.code})', e);
      throw CameraOpenException(_problemFor(e));
    } on PlatformException catch (e) {
      // e.g. `channel-error` / MissingPlugin: the native camera plugin isn't
      // registered in the running app — a full rebuild (not hot restart) is
      // needed after adding the plugin.
      AppLogger.e('Camera: native plugin unreachable (${e.code})', e);
      throw const CameraOpenException(CameraProblem.unavailable);
    }
    if (cameras.isEmpty) {
      throw const CameraOpenException(CameraProblem.unavailable);
    }

    final wanted = lens == SnapLens.front
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final description = cameras.firstWhere(
      (c) => c.lensDirection == wanted,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      // Snaps are portrait-only; keep captures upright regardless of how the
      // phone is held.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      return _PluginSession(
        controller,
        description.lensDirection == CameraLensDirection.front
            ? SnapLens.front
            : SnapLens.back,
        minZoom,
        // Beyond ~5x is mostly digital mush.
        maxZoom.clamp(1.0, 5.0),
      );
    } on CameraException catch (e) {
      await _safeDispose(controller);
      AppLogger.e('Camera: open failed (${e.code})', e);
      throw CameraOpenException(_problemFor(e));
    } on PlatformException catch (e) {
      await _safeDispose(controller);
      AppLogger.e('Camera: native plugin unreachable (${e.code})', e);
      throw const CameraOpenException(CameraProblem.unavailable);
    }
  }

  static Future<void> _safeDispose(CameraController c) async {
    try {
      await c.dispose();
    } catch (_) {
      // Already failed to open; nothing more to release.
    }
  }

  static CameraProblem _problemFor(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
        return CameraProblem.denied;
      case 'CameraAccessDeniedWithoutPrompt':
        return CameraProblem.deniedForever;
      case 'CameraAccessRestricted':
        return CameraProblem.restricted;
      default:
        return CameraProblem.unavailable;
    }
  }
}

class _PluginSession implements CameraSession {
  final CameraController _c;
  @override
  final SnapLens lens;
  @override
  final double minZoom;
  @override
  final double maxZoom;

  _PluginSession(this._c, this.lens, this.minZoom, this.maxZoom);

  @override
  bool get hasFlash => lens == SnapLens.back;

  @override
  double get previewAspectRatio {
    // The plugin reports landscape sensor ratio (w > h); we are portrait.
    final r = _c.value.aspectRatio;
    return r == 0 ? 3 / 4 : 1 / r;
  }

  @override
  Widget buildPreview() => CameraPreview(_c);

  @override
  Future<void> setFlash(SnapFlash mode) => _c.setFlashMode(switch (mode) {
    SnapFlash.off => FlashMode.off,
    SnapFlash.auto => FlashMode.auto,
    SnapFlash.on => FlashMode.always,
  });

  @override
  Future<void> setZoom(double zoom) =>
      _c.setZoomLevel(zoom.clamp(minZoom, maxZoom));

  @override
  Future<void> focusAt(Offset point) async {
    try {
      await _c.setFocusPoint(point);
      await _c.setExposurePoint(point);
    } on CameraException {
      // Not every camera supports tap-to-focus; ignore.
    }
  }

  @override
  Future<String> takePicture() async => (await _c.takePicture()).path;

  @override
  Future<void> dispose() => _c.dispose();
}

import 'dart:ui' show Offset;
import 'package:flutter/widgets.dart';

enum SnapLens { back, front }

enum SnapFlash {
  off,
  auto,
  on;

  SnapFlash get next => SnapFlash.values[(index + 1) % SnapFlash.values.length];
}

/// Why the camera couldn't open. The UI shows a tailored message for each.
enum CameraProblem { denied, deniedForever, restricted, unavailable }

class CameraOpenException implements Exception {
  final CameraProblem problem;
  const CameraOpenException(this.problem);
}

/// One opened camera. Wraps the platform controller so the rest of the app
/// (and tests) never touch the `camera` plugin directly.
abstract class CameraSession {
  SnapLens get lens;
  double get minZoom;
  double get maxZoom;

  /// False for most front cameras.
  bool get hasFlash;

  /// Preview width / height in portrait.
  double get previewAspectRatio;

  Widget buildPreview();

  Future<void> setFlash(SnapFlash mode);
  Future<void> setZoom(double zoom);

  /// [point] is normalised (0..1) within the preview.
  Future<void> focusAt(Offset point);

  /// Returns the path of the captured JPEG.
  Future<String> takePicture();

  Future<void> dispose();
}

abstract class CameraService {
  /// Opens the camera for [lens] (falling back to whichever exists). Throws
  /// [CameraOpenException].
  Future<CameraSession> open(SnapLens lens);
}

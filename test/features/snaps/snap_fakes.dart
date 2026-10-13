import 'dart:typed_data';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/permissions/camera_permission_service.dart';
import 'package:deen_companion/core/permissions/notification_permission_service.dart'
    show PermissionRequestResult;
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/snaps/data/camera/camera_session.dart';
import 'package:deen_companion/features/snaps/domain/entities/snap_draft.dart';
import 'package:deen_companion/features/snaps/domain/repositories/snap_image_processor.dart';
import 'package:deen_companion/features/snaps/domain/repositories/snap_repository.dart';
import 'package:flutter/material.dart';

/// A real 1x1 PNG so Image.memory can decode it.
final tinyPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xFF,
  0xFF,
  0x3F,
  0x00,
  0x05,
  0xFE,
  0x02,
  0xFE,
  0xA7,
  0x35,
  0x81,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class FakeCameraSession implements CameraSession {
  @override
  final SnapLens lens;
  FakeCameraSession(this.lens);

  SnapFlash flash = SnapFlash.off;
  double zoom = 1;
  bool disposed = false;
  int shots = 0;
  Offset? focused;

  @override
  double get minZoom => 1;
  @override
  double get maxZoom => 4;
  @override
  bool get hasFlash => lens == SnapLens.back;
  @override
  double get previewAspectRatio => 3 / 4;
  @override
  Widget buildPreview() => const ColoredBox(color: Colors.blueGrey);
  @override
  Future<void> setFlash(SnapFlash mode) async => flash = mode;
  @override
  Future<void> setZoom(double z) async => zoom = z;
  @override
  Future<void> focusAt(Offset point) async => focused = point;
  @override
  Future<String> takePicture() async {
    shots++;
    return '/tmp/fake_capture_$shots.jpg';
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeCameraService implements CameraService {
  final List<SnapLens> opened = [];
  final List<FakeCameraSession> sessions = [];
  CameraProblem? problem;

  @override
  Future<CameraSession> open(SnapLens lens) async {
    opened.add(lens);
    if (problem != null) throw CameraOpenException(problem!);
    final s = FakeCameraSession(lens);
    sessions.add(s);
    return s;
  }
}

class FakeProcessor implements SnapImageProcessor {
  int editCalls = 0;
  int compressCalls = 0;
  Failure? editFailure;
  Failure? compressFailure;
  final List<String> cleaned = [];

  @override
  Future<Result<Uint8List>> prepareForEditing(String path) async {
    editCalls++;
    if (editFailure != null) return Error(editFailure!);
    return Success(tinyPng);
  }

  @override
  Future<Result<PreparedImage>> compressForUpload(Uint8List cropped) async {
    compressCalls++;
    if (compressFailure != null) return Error(compressFailure!);
    return const Success(
      PreparedImage(
        path: '/tmp/prepared.jpg',
        originalBytes: 4000,
        compressedBytes: 1000,
      ),
    );
  }

  @override
  Future<void> cleanUp(Iterable<String> paths) async => cleaned.addAll(paths);
}

class FakeSnapRepository implements SnapRepository {
  Failure? failure;
  final List<SnapDraft> sent = [];

  @override
  Future<Result<SentSnap>> sendSnap(SnapDraft draft) async {
    sent.add(draft);
    if (failure != null) return Error(failure!);
    return const Success(SentSnap(id: 's1'));
  }
}

/// A Failure we can construct in tests.
const serverFailure = ServerFailure('upload failed');

class FakeCameraPermission implements CameraPermissionService {
  bool granted;
  bool permanentlyDenied;
  PermissionRequestResult nextResult;
  int requests = 0;
  int settingsOpened = 0;

  FakeCameraPermission({
    this.granted = false,
    this.permanentlyDenied = false,
    this.nextResult = PermissionRequestResult.granted,
  });

  @override
  Future<bool> isGranted() async => granted;
  @override
  Future<bool> isPermanentlyDenied() async => permanentlyDenied;
  @override
  Future<PermissionRequestResult> request() async {
    requests++;
    if (nextResult == PermissionRequestResult.granted) granted = true;
    return nextResult;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../constants/app_constants.dart';
import '../storage/local_storage_service.dart';
import '../utils/logger.dart';
import 'notification_permission_service.dart' show PermissionRequestResult;

abstract class CameraPermissionService {
  Future<bool> isGranted();

  /// True once Android/iOS will no longer show the prompt (user chose "don't
  /// ask again", or it's restricted) — the only way forward is Settings.
  Future<bool> isPermanentlyDenied();

  Future<PermissionRequestResult> request();
  Future<void> openSettings();
}

class PermissionHandlerCameraService implements CameraPermissionService {
  const PermissionHandlerCameraService();

  @override
  Future<bool> isGranted() async {
    try {
      return await ph.Permission.camera.isGranted;
    } catch (error) {
      AppLogger.e('Camera permission check failed', error);
      return false;
    }
  }

  @override
  Future<bool> isPermanentlyDenied() async {
    try {
      final s = await ph.Permission.camera.status;
      return s.isPermanentlyDenied || s.isRestricted;
    } catch (error) {
      AppLogger.e('Camera permission status failed', error);
      return false;
    }
  }

  @override
  Future<PermissionRequestResult> request() async {
    try {
      final status = await ph.Permission.camera.request();
      if (status.isGranted) return PermissionRequestResult.granted;
      if (status.isPermanentlyDenied) {
        return PermissionRequestResult.permanentlyDenied;
      }
      return PermissionRequestResult.denied;
    } catch (error) {
      AppLogger.e('Camera permission request failed', error);
      return PermissionRequestResult.denied;
    }
  }

  @override
  Future<void> openSettings() async {
    await ph.openAppSettings();
  }
}

final cameraPermissionServiceProvider = Provider<CameraPermissionService>(
  (ref) => const PermissionHandlerCameraService(),
);

/// Asks for camera access once, at startup, alongside the other permissions.
/// Skips if already granted or if it has been asked before (the camera screen
/// has its own recovery for a denial).
Future<void> requestCameraPermissionOnce({
  required LocalStorageService storage,
  required CameraPermissionService service,
}) async {
  const box = AppConstants.settingsBoxName;
  const key = AppConstants.cameraPermissionAskedKey;
  if (storage.get<bool>(box, key) == true) return;

  if (await service.isGranted()) return;
  await storage.put(box, key, true);
  await service.request();
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:permission_handler/permission_handler.dart' show Permission;
import '../utils/logger.dart';

enum PermissionRequestResult { granted, denied, permanentlyDenied }

abstract class NotificationPermissionService {
  Future<bool> isGranted();
  Future<PermissionRequestResult> request();
  Future<void> openAppSettings();
}

class PermissionHandlerNotificationService
    implements NotificationPermissionService {
  const PermissionHandlerNotificationService();

  @override
  Future<bool> isGranted() async {
    try {
      return await Permission.notification.isGranted;
    } catch (error) {
      AppLogger.e('Notification permission check failed', error);
      return false;
    }
  }

  @override
  Future<PermissionRequestResult> request() async {
    try {
      final status = await Permission.notification.request();
      if (status.isGranted) return PermissionRequestResult.granted;
      if (status.isPermanentlyDenied) {
        return PermissionRequestResult.permanentlyDenied;
      }
      return PermissionRequestResult.denied;
    } catch (error) {
      AppLogger.e('Notification permission request failed', error);
      return PermissionRequestResult.denied;
    }
  }

  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}

final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>((ref) {
      return const PermissionHandlerNotificationService();
    });

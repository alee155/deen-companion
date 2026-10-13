import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/permissions/camera_permission_service.dart';
import 'package:deen_companion/core/permissions/notification_permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/snaps/snap_fakes.dart';
import '../../helpers/in_memory_storage_service.dart';

void main() {
  const box = AppConstants.settingsBoxName;
  const key = AppConstants.cameraPermissionAskedKey;
  late InMemoryStorageService storage;

  setUp(() => storage = InMemoryStorageService());

  test('first launch: asks for camera access and remembers it asked', () async {
    final service = FakeCameraPermission();
    await requestCameraPermissionOnce(storage: storage, service: service);
    expect(service.requests, 1);
    expect(storage.get<bool>(box, key), isTrue);
  });

  test(
    'does not prompt again on later launches, even after a denial',
    () async {
      final service = FakeCameraPermission(
        nextResult: PermissionRequestResult.denied,
      );
      await requestCameraPermissionOnce(storage: storage, service: service);
      await requestCameraPermissionOnce(storage: storage, service: service);
      await requestCameraPermissionOnce(storage: storage, service: service);
      expect(service.requests, 1);
    },
  );

  test('already granted: never prompts', () async {
    final service = FakeCameraPermission(granted: true);
    await requestCameraPermissionOnce(storage: storage, service: service);
    expect(service.requests, 0);
  });
}

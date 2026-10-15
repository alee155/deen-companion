import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/timezone/device_timezone.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_user.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_providers.dart';
import 'package:deen_companion/features/auth/presentation/providers/timezone_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_storage_service.dart';
import '../_support/auth_fakes.dart';

class _Device implements DeviceTimezone {
  String? id;
  _Device(this.id);
  @override
  Future<String?> iana() async => id;
}

AuthUser _userIn(String? tz) => AuthUser(
  id: 'u1',
  name: 'Ali',
  email: 'a@b.c',
  isEmailVerified: true,
  timezone: tz,
);

void main() {
  late FakeAuthRepository repo;
  late _Device device;

  TimezoneSyncService make({bool signedIn = true}) {
    final storage = InMemoryStorageService();
    if (signedIn) {
      storage.put(
        AppConstants.settingsBoxName,
        AppConstants.authUserIdKey,
        'u1',
      );
    }
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repo),
        tokenStorageProvider.overrideWithValue(MemoryTokens(access: 'tok')),
        deviceTimezoneProvider.overrideWithValue(device),
      ],
    );
    addTearDown(c.dispose);
    return c.read(timezoneSyncServiceProvider);
  }

  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  setUp(() {
    repo = FakeAuthRepository()..meResult = Success(_userIn('UTC'));
    device = _Device('Asia/Karachi');
  });

  test(
    'patches the backend when its timezone differs from the device',
    () async {
      expect(await make().ensure(), isTrue);
      expect(repo.timezoneUpdates, ['Asia/Karachi']);
    },
  );

  test('does not patch when they already match', () async {
    repo.meResult = Success(_userIn('Asia/Karachi'));
    expect(await make().ensure(), isTrue);
    expect(repo.timezoneUpdates, isEmpty);
  });

  test('confirms only once per device timezone', () async {
    final service = make();
    await service.ensure();
    await service.ensure();
    expect(repo.timezoneUpdates, hasLength(1));
    device.id = 'Europe/London'; // user travelled
    await service.ensure();
    expect(repo.timezoneUpdates, ['Asia/Karachi', 'Europe/London']);
  });

  test('false when the PATCH fails, and it is retried next time', () async {
    repo.updateTimezoneResult = const Error(ServerFailure('nope'));
    final service = make();
    expect(await service.ensure(), isFalse);
    repo.updateTimezoneResult = const Success(null);
    expect(await service.ensure(), isTrue);
    expect(repo.timezoneUpdates, hasLength(2));
  });

  test('false when the profile cannot be read', () async {
    repo.meResult = const Error(NetworkFailure());
    expect(await make().ensure(), isFalse);
    expect(repo.timezoneUpdates, isEmpty);
  });

  test('false for guests and when the device zone is unknown', () async {
    expect(await make(signedIn: false).ensure(), isFalse);
    device.id = null;
    expect(await make().ensure(), isFalse);
    expect(repo.timezoneUpdates, isEmpty);
  });

  test('IANA check accepts names and rejects abbreviations', () {
    for (final ok in [
      'Asia/Karachi',
      'America/Argentina/Buenos_Aires',
      'UTC',
    ]) {
      expect(FlutterDeviceTimezone.looksLikeIana(ok), isTrue, reason: ok);
    }
    for (final bad in ['PKT', 'GMT+5', '+05:00', '']) {
      expect(FlutterDeviceTimezone.looksLikeIana(bad), isFalse, reason: bad);
    }
  });
}

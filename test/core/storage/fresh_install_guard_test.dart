import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/storage/fresh_install_guard.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/core/storage/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements LocalStorageService {}

class _MockTokens extends Mock implements TokenStorage {}

void main() {
  late _MockStorage storage;
  late _MockTokens tokens;

  setUp(() {
    storage = _MockStorage();
    tokens = _MockTokens();
    when(() => tokens.clear()).thenAnswer((_) async {});
    when(() => storage.put(any(), any(), any())).thenAnswer((_) async {});
  });

  FreshInstallGuard guard(TargetPlatform p) =>
      FreshInstallGuard(storage: storage, tokens: tokens, platform: p);

  test('iOS first launch clears leftover tokens and sets the marker', () async {
    when(
      () => storage.get<bool>(AppConstants.settingsBoxName, 'install_marker'),
    ).thenReturn(null);

    await guard(TargetPlatform.iOS).run();

    verify(() => tokens.clear()).called(1);
    verify(
      () => storage.put(AppConstants.settingsBoxName, 'install_marker', true),
    ).called(1);
  });

  test('iOS later launches keep the session', () async {
    when(
      () => storage.get<bool>(AppConstants.settingsBoxName, 'install_marker'),
    ).thenReturn(true);

    await guard(TargetPlatform.iOS).run();

    verifyNever(() => tokens.clear());
  });

  test(
    'Android never touches tokens, so an update cannot sign anyone out',
    () async {
      when(
        () => storage.get<bool>(AppConstants.settingsBoxName, 'install_marker'),
      ).thenReturn(null);

      await guard(TargetPlatform.android).run();

      verifyNever(() => tokens.clear());
    },
  );

  test('a failure is swallowed so start-up continues', () async {
    when(
      () => storage.get<bool>(AppConstants.settingsBoxName, 'install_marker'),
    ).thenReturn(null);
    when(() => tokens.clear()).thenThrow(Exception('keychain locked'));

    await guard(TargetPlatform.iOS).run();
  });
}

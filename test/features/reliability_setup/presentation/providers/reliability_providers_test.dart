import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/permissions/notification_permission_service.dart';
import 'package:deen_companion/features/daily_content/data/daily_notification_scheduler.dart';
import 'package:deen_companion/features/daily_content/presentation/providers/daily_content_providers.dart';
import 'package:deen_companion/features/daily_content/presentation/providers/daily_notification_service.dart';
import 'package:deen_companion/features/prayer_reminders/data/prayer_alarm_channel.dart';
import 'package:deen_companion/features/prayer_reminders/presentation/providers/reminders_provider.dart';
import 'package:deen_companion/features/reliability_setup/domain/reliability_requirement.dart';
import 'package:deen_companion/features/reliability_setup/presentation/providers/reliability_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';

class _MockScheduler extends Mock implements DailyNotificationScheduler {}

class _MockAlarm extends Mock implements PrayerAlarmChannel {}

class _MockDailyService extends Mock implements DailyNotificationService {}

class _MockReminderService extends Mock implements PrayerReminderService {}

class _FakeNotifPerm implements NotificationPermissionService {
  bool granted = true;
  PermissionRequestResult requestResult = PermissionRequestResult.granted;
  int requests = 0;
  int openSettings = 0;
  @override
  Future<bool> isGranted() async => granted;
  @override
  Future<PermissionRequestResult> request() async {
    requests++;
    return requestResult;
  }

  @override
  Future<void> openAppSettings() async => openSettings++;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late PaStorage storage;
  late PaLocation location;
  late _FakeNotifPerm notif;
  late _MockScheduler scheduler;
  late _MockAlarm alarm;
  late _MockDailyService daily;
  late _MockReminderService reminders;

  setUpAll(initFlavorForTests);

  setUp(() {
    storage = PaStorage();
    location = PaLocation();
    notif = _FakeNotifPerm();
    scheduler = _MockScheduler();
    alarm = _MockAlarm();
    daily = _MockDailyService();
    reminders = _MockReminderService();
    when(() => scheduler.canScheduleExact()).thenAnswer((_) async => true);
    when(() => scheduler.requestExactAlarmPermission()).thenAnswer((_) async => true);
    when(() => alarm.canUseFullScreenIntent()).thenAnswer((_) async => true);
    when(() => alarm.isIgnoringBatteryOptimizations()).thenAnswer((_) async => true);
    when(() => alarm.openFullScreenIntentSettings()).thenAnswer((_) async {});
    when(() => alarm.requestIgnoreBatteryOptimizations()).thenAnswer((_) async {});
    when(() => daily.sync()).thenAnswer((_) async {});
    when(() => reminders.syncIfEnabled()).thenAnswer((_) async => const ReminderSyncDisabled());
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        locationServiceProvider.overrideWithValue(location),
        notificationPermissionServiceProvider.overrideWithValue(notif),
        dailyNotificationSchedulerProvider.overrideWithValue(scheduler),
        prayerAlarmChannelProvider.overrideWithValue(alarm),
        dailyNotificationServiceProvider.overrideWithValue(daily),
        prayerReminderServiceProvider.overrideWithValue(reminders),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  ReliabilityService svc(ProviderContainer c) => c.read(reliabilityServiceProvider);

  group('check()', () {
    test('everything granted on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final s = await svc(make()).check();
      expect(s.allGranted, isTrue);
      expect(s.keys, ReliabilityRequirement.values);
    });

    test('reports each Android requirement independently', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => scheduler.canScheduleExact()).thenAnswer((_) async => false);
      when(() => alarm.isIgnoringBatteryOptimizations()).thenAnswer((_) async => false);
      notif.granted = false;
      location.availability = const LocationAvailability(
        serviceEnabled: true, hasPermission: false, permanentlyDenied: false);
      final s = await svc(make()).check();
      expect(s.missing, [
        ReliabilityRequirement.location,
        ReliabilityRequirement.notifications,
        ReliabilityRequirement.exactAlarms,
        ReliabilityRequirement.batteryOptimization,
      ]);
      expect(s[ReliabilityRequirement.fullScreenAlerts], isTrue);
    });

    test('location counts only when permission is granted (service state is separate)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      location.availability = const LocationAvailability(
        serviceEnabled: false, hasPermission: true, permanentlyDenied: false);
      final s = await svc(make()).check();
      expect(s[ReliabilityRequirement.location], isTrue);
    });

    test('non-Android: Android-only gates are assumed fine and never queried', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => scheduler.canScheduleExact()).thenAnswer((_) async => false);
      final s = await svc(make()).check();
      expect(s[ReliabilityRequirement.exactAlarms], isTrue);
      expect(s[ReliabilityRequirement.fullScreenAlerts], isTrue);
      expect(s[ReliabilityRequirement.batteryOptimization], isTrue);
      verifyNever(() => scheduler.canScheduleExact());
      verifyNever(() => alarm.canUseFullScreenIntent());
    });
  });

  group('request()', () {
    test('location: prompts; opens app settings only when permanently denied', () async {
      final c = make();
      location.requestResult = const LocationAvailability(
        serviceEnabled: true, hasPermission: false, permanentlyDenied: false);
      await svc(c).request(ReliabilityRequirement.location);
      expect(location.requestPermissionCalls, 1);
      expect(location.openAppSettingsCalls, 0);
    });

    test('location permanently denied sends the user to settings and waits for resume', () async {
      final c = make();
      location.requestResult = const LocationAvailability(
        serviceEnabled: true, hasPermission: false, permanentlyDenied: true);
      var done = false;
      final f = svc(c).request(ReliabilityRequirement.location).then((_) => done = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(location.openAppSettingsCalls, 1);
      expect(done, isFalse, reason: 'must wait for the user to come back');
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await f;
      expect(done, isTrue);
    });

    test('notifications granted: no settings detour', () async {
      final c = make();
      await svc(c).request(ReliabilityRequirement.notifications);
      expect(notif.requests, 1);
      expect(notif.openSettings, 0);
    });

    test('notifications permanently denied: opens settings and waits for resume', () async {
      final c = make();
      notif.requestResult = PermissionRequestResult.permanentlyDenied;
      final f = svc(c).request(ReliabilityRequirement.notifications);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notif.openSettings, 1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await f;
    });

    test('exact alarms delegates to the scheduler', () async {
      await svc(make()).request(ReliabilityRequirement.exactAlarms);
      verify(() => scheduler.requestExactAlarmPermission()).called(1);
    });

    test('full-screen and battery open their system screens then await resume', () async {
      final c = make();
      final f1 = svc(c).request(ReliabilityRequirement.fullScreenAlerts);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      verify(() => alarm.openFullScreenIntentSettings()).called(1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await f1;

      final f2 = svc(c).request(ReliabilityRequirement.batteryOptimization);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      verify(() => alarm.requestIgnoreBatteryOptimizations()).called(1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await f2;
    });

    test('a throwing platform call is swallowed and the status is refreshed', () async {
      when(() => scheduler.requestExactAlarmPermission()).thenThrow(StateError('x'));
      final c = make();
      await svc(c).request(ReliabilityRequirement.exactAlarms);
    });

    test('resume invalidates the live status provider', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final c = make();
      final sub = c.listen(reliabilityStatusProvider, (_, _) {});
      addTearDown(sub.close);
      svc(c);
      expect((await c.read(reliabilityStatusProvider.future)).allGranted, isTrue);
      notif.granted = false;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final after = await c.read(reliabilityStatusProvider.future);
      expect(after[ReliabilityRequirement.notifications], isFalse);
    });
  });

  group('setUpAll()', () {
    test('asks only for what is missing, in order, one at a time, then re-arms', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      notif.granted = false;
      var batteryOk = false;
      when(() => alarm.isIgnoringBatteryOptimizations()).thenAnswer((_) async => batteryOk);
      when(() => alarm.requestIgnoreBatteryOptimizations()).thenAnswer((_) async {
        batteryOk = true;
      });
      notif.requestResult = PermissionRequestResult.granted;
      // Granting notifications flips the status for the next check.
      final c = make();
      final steps = <ReliabilityRequirement?>[];
      final run = svc(c).setUpAll(onStep: steps.add);
      // notifications (no wait) then battery (waits for resume)
      await Future<void>.delayed(const Duration(milliseconds: 50));
      notif.granted = true;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await run;
      expect(steps.first, ReliabilityRequirement.notifications);
      expect(steps.last, isNull);
      expect(steps, contains(ReliabilityRequirement.batteryOptimization));
      verifyNever(() => scheduler.requestExactAlarmPermission());
      verify(() => daily.sync()).called(1);
      verify(() => reminders.syncIfEnabled()).called(1);
    });

    test('with nothing missing it makes no requests but still re-arms', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final steps = <ReliabilityRequirement?>[];
      await svc(make()).setUpAll(onStep: steps.add);
      expect(steps, [null]);
      expect(notif.requests, 0);
      verify(() => daily.sync()).called(1);
    });

    test('a second call while one is running is ignored', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => alarm.isIgnoringBatteryOptimizations()).thenAnswer((_) async => false);
      final c = make();
      final first = svc(c).setUpAll();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await svc(c).setUpAll(); // returns immediately
      verifyNever(() => daily.sync());
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await first;
      verify(() => daily.sync()).called(1);
    });
  });

  group('prompt cadence', () {
    const box = AppConstants.settingsBoxName;

    test('never prompted -> should prompt', () {
      expect(svc(make()).shouldPrompt(), isTrue);
    });

    test('markPrompted stores now and suppresses the prompt', () async {
      final c = make();
      await svc(c).markPrompted();
      final stored = storage.boxes[box]![AppConstants.reliabilityPromptedAtKey] as int;
      expect(
        (DateTime.now().millisecondsSinceEpoch - stored).abs(),
        lessThan(5000),
      );
      expect(svc(c).shouldPrompt(), isFalse);
    });

    test('prompts again only after more than 24 hours', () {
      final c = make();
      int ago(Duration d) => DateTime.now().subtract(d).millisecondsSinceEpoch;
      storage.boxes[box] = {
        AppConstants.reliabilityPromptedAtKey: ago(const Duration(hours: 23, minutes: 59)),
      };
      expect(svc(c).shouldPrompt(), isFalse);
      storage.boxes[box] = {
        AppConstants.reliabilityPromptedAtKey: ago(const Duration(hours: 24, minutes: 1)),
      };
      expect(svc(c).shouldPrompt(), isTrue);
    });

    test('a timestamp in the future never prompts', () {
      storage.boxes[box] = {
        AppConstants.reliabilityPromptedAtKey:
            DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch,
      };
      expect(svc(make()).shouldPrompt(), isFalse);
    });
  });
}

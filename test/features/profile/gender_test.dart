import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/timezone/device_timezone.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/data/models/auth_user_model.dart';
import 'package:deen_companion/features/auth/domain/entities/gender.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_providers.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/auth/presentation/screens/signup_screen.dart';
import 'package:deen_companion/features/profile/data/models/profile_models.dart';
import 'package:deen_companion/features/profile/domain/entities/user_profile.dart';
import 'package:deen_companion/features/profile/domain/repositories/profile_repository.dart';
import 'package:deen_companion/features/profile/presentation/providers/gender_prompt_providers.dart';
import 'package:deen_companion/features/profile/presentation/providers/profile_providers.dart';
import 'package:deen_companion/features/profile/presentation/widgets/gender_prompt_sheet.dart';
import 'package:deen_companion/features/special_days/domain/special_days.dart';
import 'package:deen_companion/features/special_days/presentation/providers/special_days_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/_support/auth_fakes.dart';
import '../prayer_logs/presentation/_prayer_log_test_support.dart';
import '../special_days/special_days_screen_test.dart' show FakeSpecialDaysRepo;

class _NoTimezone implements DeviceTimezone {
  @override
  Future<String?> iana() async => null;
}

class _Profiles implements ProfileRepository {
  Gender? gender;
  Result<void> setResult = const Success(null);
  final List<Gender> sent = [];
  int reads = 0;

  _Profiles({this.gender});

  @override
  Future<Result<UserProfile>> getProfile() async {
    reads++;
    return Success(
      UserProfile(id: 'me', name: 'Me', email: 'me@b.c', gender: gender),
    );
  }

  @override
  Future<Result<void>> setGender(Gender g) async {
    sent.add(g);
    if (setResult is Success) gender = g;
    return setResult;
  }

  @override
  Future<Result<UserProfile>> updateProfile({
    String? name,
    String? imagePath,
  }) => throw UnimplementedError();
  @override
  Future<Result<UserProfile>> removeAvatar() => throw UnimplementedError();
  @override
  Future<Result<UserPoints>> getPoints() async =>
      const Success(UserPoints.empty);
  @override
  Future<Result<void>> setTimezone(String timezone) async =>
      const Success(null);
}

List<Override> _overrides(_Profiles profiles) => [
  authSessionProvider.overrideWith(SignedIn.new),
  deviceTimezoneProvider.overrideWithValue(_NoTimezone()),
  profileRepositoryProvider.overrideWithValue(profiles),
  specialDaysRepositoryProvider.overrideWithValue(
    FakeSpecialDaysRepo(SpecialDays.notEligible),
  ),
];

void main() {
  group('parsing', () {
    test('Gender.parse', () {
      expect(Gender.parse('male'), Gender.male);
      expect(Gender.parse('female'), Gender.female);
      expect(Gender.parse(null), isNull);
      expect(Gender.parse('other'), isNull);
    });

    test('the auth user and the profile read the gender', () {
      final base = {'id': 'u', 'name': 'N', 'email': 'a@b.c'};
      expect(
        AuthUserModel.fromJson({...base, 'gender': 'female'}).toEntity().gender,
        Gender.female,
      );
      expect(AuthUserModel.fromJson(base).toEntity().gender, isNull);
      expect(
        userProfileFromJson({...base, 'gender': 'male'}).gender,
        Gender.male,
      );
      expect(userProfileFromJson({...base, 'gender': null}).gender, isNull);
    });
  });

  group('the one-time prompt', () {
    test('asks only a signed-in account that has no gender', () async {
      final c = ProviderContainer(overrides: _overrides(_Profiles()));
      addTearDown(c.dispose);
      final sub = c.listen(genderPromptNeededProvider, (_, _) {});
      expect(sub.read(), isFalse, reason: 'profile not loaded yet');
      await c.read(profileProvider.future);
      expect(sub.read(), isTrue);

      c.read(genderPromptDismissedProvider.notifier).state = true;
      expect(sub.read(), isFalse, reason: 'dismissed for this run');
      sub.close();
    });

    test('an account with a gender is never asked', () async {
      final c = ProviderContainer(
        overrides: _overrides(_Profiles(gender: Gender.male)),
      );
      addTearDown(c.dispose);
      final sub = c.listen(genderPromptNeededProvider, (_, _) {});
      await c.read(profileProvider.future);
      expect(sub.read(), isFalse);
      sub.close();
    });

    test('saving sends it, then reads the profile again', () async {
      final profiles = _Profiles();
      final c = ProviderContainer(overrides: _overrides(profiles));
      addTearDown(c.dispose);
      final keep = c.listen(profileProvider, (_, _) {});
      await c.read(profileProvider.future);
      final reads = profiles.reads;

      final ok = await c
          .read(genderPromptControllerProvider.notifier)
          .save(Gender.female);
      expect(ok, isTrue);
      expect(profiles.sent, [Gender.female]);
      await c.read(profileProvider.future);
      expect(profiles.reads, greaterThan(reads));
      expect(c.read(profileProvider).value!.gender, Gender.female);
      keep.close();
    });

    test('"already set" counts as done: nothing to ask any more', () async {
      final profiles = _Profiles(gender: Gender.male)
        ..setResult = const Error(GenderAlreadySet());
      final c = ProviderContainer(overrides: _overrides(profiles));
      addTearDown(c.dispose);
      final ok = await c
          .read(genderPromptControllerProvider.notifier)
          .save(Gender.female);
      expect(ok, isTrue);
    });

    test('any other failure keeps the prompt and says why', () async {
      final profiles = _Profiles()
        ..setResult = const Error(ServerFailure('Try later'));
      final c = ProviderContainer(overrides: _overrides(profiles));
      addTearDown(c.dispose);
      final keep = c.listen(genderPromptControllerProvider, (_, _) {});
      final ok = await c
          .read(genderPromptControllerProvider.notifier)
          .save(Gender.female);
      expect(ok, isFalse);
      expect(c.read(genderPromptControllerProvider).errorMessage, 'Try later');
      keep.close();
    });

    testWidgets('the sheet appears, needs a choice, and saves it', (
      tester,
    ) async {
      final profiles = _Profiles();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(profiles),
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => const MaterialApp(
              home: GenderPromptHost(child: Scaffold(body: Text('home'))),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('One quick question'), findsOneWidget);
      expect(find.textContaining('only set this once'), findsOneWidget);

      // Save waits for a choice.
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.tap(find.text('Female'));
      await tester.pump();
      await tester.tap(save);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(profiles.sent, [Gender.female]);
      expect(find.text('One quick question'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('"Not now" closes it and it is not shown again this run', (
      tester,
    ) async {
      final profiles = _Profiles();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(profiles),
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => const MaterialApp(
              home: GenderPromptHost(child: Scaffold(body: Text('home'))),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.text('Not now'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('One quick question'), findsNothing);
      expect(profiles.sent, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('sign-up asks for the gender', () {
    late FakeAuthRepository auth;

    Future<void> pump(WidgetTester tester) async {
      auth = FakeAuthRepository()..signupResult = const Success(unverifiedUser);
      tester.view.physicalSize = const Size(390 * 3, 1700 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp.router(
              // The test font is much wider than the real one, so the existing
              // sign-up rows only fit at a smaller text size.
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(0.6)),
                child: child!,
              ),
              routerConfig: GoRouter(
                routes: [
                  GoRoute(path: '/', builder: (_, _) => const SignupScreen()),
                  GoRoute(
                    path: '/otp',
                    builder: (_, _) => const Scaffold(body: Text('OTP PAGE')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> fill(WidgetTester tester) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Alee Khan');
      await tester.enterText(fields.at(1), 'alee@example.com');
      await tester.enterText(fields.at(2), 'password123');
    }

    testWidgets('no gender chosen: it says so and nothing is sent', (
      tester,
    ) async {
      await pump(tester);
      await fill(tester);
      await tester.tap(find.text('Create Account').last);
      await tester.pump();
      expect(find.text('Choose your gender'), findsOneWidget);
      expect(auth.lastGender, isNull);
      expect(find.text('OTP PAGE'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the chosen gender goes with the sign-up', (tester) async {
      await pump(tester);
      await fill(tester);
      await tester.tap(find.text('Female'));
      await tester.pump();
      expect(find.text('Choose your gender'), findsNothing);
      await tester.tap(find.text('Create Account').last);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(auth.lastGender, Gender.female);
      expect(find.text('OTP PAGE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the choice can be switched before sending', (tester) async {
      await pump(tester);
      await fill(tester);
      await tester.tap(find.text('Female'));
      await tester.pump();
      await tester.tap(find.text('Male'));
      await tester.pump();
      await tester.tap(find.text('Create Account').last);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(auth.lastGender, Gender.male);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

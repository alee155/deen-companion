import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_user.dart';
import 'package:deen_companion/features/auth/domain/entities/social_sign_in.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_providers.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/auth/presentation/providers/social_auth_controller.dart';
import 'package:deen_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:deen_companion/features/auth/presentation/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/in_memory_storage_service.dart';
import '../_support/auth_fakes.dart';

const _sara = AuthUser(
  id: 'u2',
  name: 'Sara Ahmed',
  email: 's@b.c',
  isEmailVerified: true,
);

late FakeAuthRepository _repo;
late ProviderContainer _container;

/// [screen] is mounted at `/`; a signed-in person is sent to `/home`.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  _repo = FakeAuthRepository();
  _container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_repo),
      tokenStorageProvider.overrideWithValue(MemoryTokens()),
      localStorageServiceProvider.overrideWithValue(InMemoryStorageService()),
    ],
  );
  addTearDown(_container.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.6)),
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('login screen', () {
    testWidgets('shows Google, and Apple where it is supported', (
      tester,
    ) async {
      await _pump(tester, const LoginScreen());
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    testWidgets('hides Apple where it is not supported', (tester) async {
      await _pump(tester, const LoginScreen());
      _repo.appleSupported = false;
      _container.invalidate(appleSignInSupportedProvider);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
    });

    testWidgets('Google signs in and leaves the screen', (tester) async {
      await _pump(tester, const LoginScreen(redirect: '/home'));
      _repo.googleResult = const Success(
        SocialSignIn(user: _sara, isNewUser: true),
      );
      await _tap(tester, 'Continue with Google');
      expect(_repo.googleCalls, 1);
      expect(find.text('HOME'), findsOneWidget);
      expect(_container.read(authSessionProvider).userId, 'u2');
    });

    testWidgets('Apple signs in and leaves the screen', (tester) async {
      await _pump(tester, const LoginScreen(redirect: '/home'));
      _repo.appleResult = const Success(
        SocialSignIn(user: _sara, isNewUser: false),
      );
      await _tap(tester, 'Continue with Apple');
      expect(_repo.appleCalls, 1);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('closing the sheet shows nothing and stays here', (
      tester,
    ) async {
      await _pump(tester, const LoginScreen(redirect: '/home'));
      _repo.googleResult = const Success(null);
      await _tap(tester, 'Continue with Google');
      expect(_repo.googleCalls, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('HOME'), findsNothing);
      expect(_container.read(authSessionProvider).isAuthenticated, isFalse);
    });

    testWidgets('a failure shows its message and stays here', (tester) async {
      await _pump(tester, const LoginScreen(redirect: '/home'));
      _repo.googleResult = const Error(
        ServerFailure(
          'We couldn’t verify your Google sign-in. Please try again.',
        ),
      );
      await _tap(tester, 'Continue with Google');
      expect(
        find.text('We couldn’t verify your Google sign-in. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('HOME'), findsNothing);
      // Nothing is left busy, so the buttons work again.
      expect(_container.read(socialAuthControllerProvider).isBusy, isFalse);
    });
  });

  group('sign-up screen', () {
    testWidgets('offers both too, and Google signs in from it', (tester) async {
      await _pump(tester, const SignupScreen(redirect: '/home'));
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      _repo.googleResult = const Success(
        SocialSignIn(user: _sara, isNewUser: true),
      );
      await _tap(tester, 'Continue with Google');
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}

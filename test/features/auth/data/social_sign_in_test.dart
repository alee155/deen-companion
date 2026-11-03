import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/timezone/device_timezone.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:deen_companion/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:deen_companion/features/auth/domain/entities/social_sign_in.dart';
import 'package:deen_companion/features/auth/domain/services/social_auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../_support/dio_test_support.dart';
import '../_support/auth_fakes.dart';

class _FixedTimezone implements DeviceTimezone {
  @override
  Future<String?> iana() async => 'Asia/Karachi';
}

/// The provider sheets, answering as the test says.
class _Sheets implements SocialAuthService {
  SocialCredential? googleAnswer = const SocialCredential(idToken: 'g-token');
  SocialCredential? appleAnswer = const SocialCredential(
    idToken: 'a-token',
    authorizationCode: 'a-code',
    name: 'Sara Ahmed',
  );
  Object? throws;
  int shown = 0;

  @override
  Future<SocialCredential?> google() async {
    shown++;
    if (throws != null) throw throws!;
    return googleAnswer;
  }

  @override
  Future<SocialCredential?> apple() async {
    shown++;
    if (throws != null) throw throws!;
    return appleAnswer;
  }

  @override
  bool get appleSupported => true;
}

DioException _http(int status, Map<String, dynamic> body) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: body,
    requestOptions: RequestOptions(path: '/'),
  ),
);

Map<String, dynamic> _session({bool isNew = false, bool verified = true}) => {
  'success': true,
  'data': {
    'accessToken': 'tok',
    'isNewUser': isNew,
    'user': {
      'id': 'u1',
      'name': 'Sara Ahmed',
      'email': 's@b.c',
      'isEmailVerified': verified,
      'gender': null,
    },
  },
};

void main() {
  late MockDio dio;
  late MemoryTokens tokens;
  late _Sheets sheets;
  late AuthRepositoryImpl repo;

  setUp(() {
    dio = MockDio();
    tokens = MemoryTokens();
    sheets = _Sheets();
    repo = AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(dio),
      tokenStorage: tokens,
      deviceTimezone: _FixedTimezone(),
      social: sheets,
    );
  });

  When<Future<Response<dynamic>>> post() =>
      when(() => dio.post(any(), data: any(named: 'data')));

  Failure failureOf(Result<SocialSignIn?> r) =>
      (r as Error<SocialSignIn?>).failure;

  group('Google', () {
    test(
      'sends the ID token and the timezone, and keeps the session',
      () async {
        post().thenAnswer((_) async => okResponse(_session(isNew: true)));
        final r = await repo.signInWithGoogle();

        final signIn = (r as Success<SocialSignIn?>).data!;
        expect(signIn.isNewUser, isTrue);
        expect(signIn.user.id, 'u1');
        expect(signIn.user.gender, isNull);
        // Verified at once: an active token, nothing parked for an OTP.
        expect(tokens.access, 'tok');
        expect(tokens.pending, isNull);
        verify(
          () => dio.post(
            ApiEndpoints.authGoogle,
            data: {'idToken': 'g-token', 'timezone': 'Asia/Karachi'},
          ),
        ).called(1);
      },
    );

    test('an existing account is not new', () async {
      post().thenAnswer((_) async => okResponse(_session()));
      final r = await repo.signInWithGoogle();
      expect((r as Success<SocialSignIn?>).data!.isNewUser, isFalse);
    });

    test('closing the sheet is not an error and calls nothing', () async {
      sheets.googleAnswer = null;
      final r = await repo.signInWithGoogle();
      expect(r, isA<Success<SocialSignIn?>>());
      expect((r as Success<SocialSignIn?>).data, isNull);
      expect(tokens.access, isNull);
      verifyNever(() => dio.post(any(), data: any(named: 'data')));
    });

    test('a sheet failure shows its own sentence', () async {
      sheets.throws = const SocialAuthException(
        'Couldn’t sign in with Google.',
      );
      expect(
        failureOf(await repo.signInWithGoogle()).message,
        'Couldn’t sign in with Google.',
      );
      expect(tokens.access, isNull);
    });
  });

  group('Apple', () {
    test('sends the token, the code and the name', () async {
      post().thenAnswer((_) async => okResponse(_session(isNew: true)));
      final r = await repo.signInWithApple();
      expect((r as Success<SocialSignIn?>).data!.isNewUser, isTrue);
      expect(tokens.access, 'tok');
      verify(
        () => dio.post(
          ApiEndpoints.authApple,
          data: {
            'idToken': 'a-token',
            'authorizationCode': 'a-code',
            'name': 'Sara Ahmed',
            'timezone': 'Asia/Karachi',
          },
        ),
      ).called(1);
    });

    test('with no name (a later sign-in) the name is left out', () async {
      sheets.appleAnswer = const SocialCredential(
        idToken: 'a-token',
        authorizationCode: 'a-code',
      );
      post().thenAnswer((_) async => okResponse(_session()));
      await repo.signInWithApple();
      verify(
        () => dio.post(
          ApiEndpoints.authApple,
          data: {
            'idToken': 'a-token',
            'authorizationCode': 'a-code',
            'timezone': 'Asia/Karachi',
          },
        ),
      ).called(1);
    });

    test('closing the sheet is not an error', () async {
      sheets.appleAnswer = null;
      final r = await repo.signInWithApple();
      expect((r as Success<SocialSignIn?>).data, isNull);
    });

    test('it is offered only where the service supports it', () {
      expect(repo.appleSignInSupported, isTrue);
      final none = AuthRepositoryImpl(
        remote: AuthRemoteDataSourceImpl(dio),
        tokenStorage: tokens,
      );
      expect(none.appleSignInSupported, isFalse);
    });
  });

  group('errors', () {
    Future<String> messageFor(DioException e, {bool apple = false}) async {
      post().thenThrow(e);
      return failureOf(
        apple ? await repo.signInWithApple() : await repo.signInWithGoogle(),
      ).message;
    }

    test('a bad token reads plainly', () async {
      expect(
        await messageFor(
          _http(401, {'success': false, 'message': 'Invalid Google token'}),
        ),
        'We couldn’t verify your Google sign-in. Please try again.',
      );
      expect(
        await messageFor(
          _http(401, {'success': false, 'message': 'Invalid Apple token'}),
          apple: true,
        ),
        'We couldn’t verify your Apple sign-in. Please try again.',
      );
    });

    test('no verified email', () async {
      expect(
        await messageFor(
          _http(400, {
            'success': false,
            'message': 'Your account has no verified email address',
          }),
        ),
        contains('verified email address from your Google account'),
      );
    });

    test('a deactivated account', () async {
      expect(
        await messageFor(
          _http(401, {'success': false, 'message': 'Invalid credentials'}),
        ),
        'This account can’t be used to sign in right now.',
      );
    });

    test('the email already belongs to another sign-in', () async {
      expect(
        await messageFor(
          _http(409, {
            'success': false,
            'message': 'Email already linked to another account',
          }),
        ),
        contains('already linked to a different Google account'),
      );
    });

    test('the server is not set up for it', () async {
      expect(
        await messageFor(
          _http(503, {
            'success': false,
            'message': 'Google sign-in is not configured',
          }),
        ),
        contains('isn’t available right now'),
      );
    });

    test('offline is a network failure and keeps no session', () async {
      post().thenThrow(dioError());
      expect(failureOf(await repo.signInWithGoogle()), isA<NetworkFailure>());
      expect(tokens.access, isNull);
    });

    test('an unverified email in the answer is refused', () async {
      post().thenAnswer((_) async => okResponse(_session(verified: false)));
      expect(failureOf(await repo.signInWithGoogle()), isA<ServerFailure>());
      expect(tokens.access, isNull);
    });

    test('without the sheets there is nothing to sign in with', () async {
      final none = AuthRepositoryImpl(
        remote: AuthRemoteDataSourceImpl(dio),
        tokenStorage: tokens,
      );
      expect(
        failureOf(await none.signInWithGoogle()),
        isA<UnexpectedFailure>(),
      );
    });
  });
}

import 'package:deen_companion/features/auth/domain/entities/gender.dart';
import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:deen_companion/features/auth/domain/entities/otp_purpose.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../_support/dio_test_support.dart';

const _user = {
  'id': '354176d6',
  'name': 'Alee',
  'email': 'a@b.c',
  'isActive': true,
  'isEmailVerified': false,
};

DioException _http(int status, Object? body) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: body,
    requestOptions: RequestOptions(path: '/'),
  ),
);

void main() {
  late MockDio dio;
  late AuthRemoteDataSourceImpl ds;

  setUp(() {
    dio = MockDio();
    ds = AuthRemoteDataSourceImpl(dio);
  });

  void stubPost(Object answer) {
    final call = when(() => dio.post(any(), data: any(named: 'data')));
    if (answer is Exception) {
      call.thenThrow(answer);
    } else {
      call.thenAnswer((_) async => okResponse(answer));
    }
  }

  test('register posts the body and parses token + user', () async {
    stubPost({
      'success': true,
      'data': {'accessToken': 'tok', 'user': _user},
    });
    final r = await ds.register(
      name: 'Alee',
      email: 'a@b.c',
      password: 'pw',
      gender: Gender.female,
    );
    expect(r.accessToken, 'tok');
    expect(r.user.email, 'a@b.c');
    expect(r.user.isEmailVerified, isFalse);
    verify(
      () => dio.post(
        ApiEndpoints.authRegister,
        data: {
          'name': 'Alee',
          'email': 'a@b.c',
          'password': 'pw',
          'gender': 'female',
        },
      ),
    ).called(1);
  });

  test('register sends the device timezone when given', () async {
    stubPost({
      'success': true,
      'data': {'accessToken': 'tok', 'user': _user},
    });
    await ds.register(
      name: 'Alee',
      email: 'a@b.c',
      password: 'pw',
      gender: Gender.female,
      timezone: 'Asia/Karachi',
    );
    verify(
      () => dio.post(
        ApiEndpoints.authRegister,
        data: {
          'name': 'Alee',
          'email': 'a@b.c',
          'password': 'pw',
          'gender': 'female',
          'timezone': 'Asia/Karachi',
        },
      ),
    ).called(1);
  });

  test('user timezone is parsed when present', () async {
    stubPost({
      'success': true,
      'data': {
        'accessToken': 'tok',
        'user': {..._user, 'timezone': 'Asia/Karachi'},
      },
    });
    final r = await ds.register(
      name: 'n',
      email: 'a@b.c',
      password: 'pw',
      gender: Gender.female,
    );
    expect(r.user.timezone, 'Asia/Karachi');
  });

  test('verifyEmail posts email + otp and parses the user', () async {
    stubPost({
      'success': true,
      'data': {
        'user': {..._user, 'isEmailVerified': true},
      },
    });
    final r = await ds.verifyEmail(email: 'a@b.c', otp: '123456');
    expect(r.user.isEmailVerified, isTrue);
    verify(
      () => dio.post(
        ApiEndpoints.authVerifyEmail,
        data: {'email': 'a@b.c', 'otp': '123456'},
      ),
    ).called(1);
  });

  test('HTTP error body message is surfaced', () async {
    stubPost(_http(400, {'message': 'Invalid OTP'}));
    expect(
      () => ds.verifyEmail(email: 'a@b.c', otp: '1'),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Invalid OTP',
        ),
      ),
    );
  });

  test('validation message lists are joined', () async {
    stubPost(
      _http(400, {
        'message': ['email must be an email', 'bad pw'],
      }),
    );
    expect(
      () => ds.register(
        name: 'n',
        email: 'x',
        password: 'p',
        gender: Gender.female,
      ),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'email must be an email\nbad pw',
        ),
      ),
    );
  });

  test('connection errors map to NetworkException', () async {
    stubPost(dioError());
    expect(
      () => ds.register(
        name: 'n',
        email: 'x',
        password: 'p',
        gender: Gender.female,
      ),
      throwsA(isA<NetworkException>()),
    );
  });

  test('success:false or malformed bodies map to ServerException', () async {
    stubPost({'success': false, 'data': {}});
    expect(
      () => ds.register(
        name: 'n',
        email: 'x',
        password: 'p',
        gender: Gender.female,
      ),
      throwsA(isA<ServerException>()),
    );
    stubPost({
      'success': true,
      'data': {'oops': 1},
    });
    expect(
      () => ds.register(
        name: 'n',
        email: 'x',
        password: 'p',
        gender: Gender.female,
      ),
      throwsA(isA<ServerException>()),
    );
  });

  group('login', () {
    test('parses token + user (even when unverified)', () async {
      stubPost({
        'success': true,
        'data': {'accessToken': 'tok', 'user': _user},
      });
      final r = await ds.login(email: 'a@b.c', password: 'password1');
      expect(r.accessToken, 'tok');
      expect(r.user.isEmailVerified, isFalse);
      verify(
        () => dio.post(
          ApiEndpoints.authLogin,
          data: {'email': 'a@b.c', 'password': 'password1'},
        ),
      ).called(1);
    });

    test('401 Invalid credentials surfaces its message', () async {
      stubPost(_http(401, {'message': 'Invalid credentials'}));
      expect(
        () => ds.login(email: 'a@b.c', password: 'password1'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Invalid credentials',
          ),
        ),
      );
    });
  });

  group('resend / forgot / reset (success-only endpoints)', () {
    test('resendOtp sends type and tolerates a body without data', () async {
      stubPost({'success': true});
      await ds.resendOtp(email: 'a@b.c', purpose: OtpPurpose.verifyEmail);
      await ds.resendOtp(email: 'a@b.c', purpose: OtpPurpose.resetPassword);
      verify(
        () => dio.post(
          ApiEndpoints.authResendOtp,
          data: {'email': 'a@b.c', 'type': 'verify_email'},
        ),
      ).called(1);
      verify(
        () => dio.post(
          ApiEndpoints.authResendOtp,
          data: {'email': 'a@b.c', 'type': 'reset_password'},
        ),
      ).called(1);
    });

    test('forgotPassword posts the email', () async {
      stubPost({
        'success': true,
        'data': {'message': 'If an account exists...'},
      });
      await ds.forgotPassword(email: 'a@b.c');
      verify(
        () =>
            dio.post(ApiEndpoints.authForgotPassword, data: {'email': 'a@b.c'}),
      ).called(1);
    });

    test('resetPassword posts email, otp and newPassword', () async {
      stubPost({'success': true});
      await ds.resetPassword(
        email: 'a@b.c',
        otp: '1234',
        newPassword: 'newPassword456',
      );
      verify(
        () => dio.post(
          ApiEndpoints.authResetPassword,
          data: {
            'email': 'a@b.c',
            'otp': '1234',
            'newPassword': 'newPassword456',
          },
        ),
      ).called(1);
    });

    test('invalid code error is surfaced', () async {
      stubPost(_http(400, {'message': 'Invalid or expired code'}));
      expect(
        () =>
            ds.resetPassword(email: 'a@b.c', otp: '0000', newPassword: 'x' * 8),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Invalid or expired code',
          ),
        ),
      );
    });
  });

  group('me / delete', () {
    test('getMe parses the flat user in data', () async {
      when(
        () => dio.get(any()),
      ).thenAnswer((_) async => okResponse({'success': true, 'data': _user}));
      final u = await ds.getMe();
      expect(u.id, '354176d6');
      expect(u.email, 'a@b.c');
      verify(() => dio.get(ApiEndpoints.authMe)).called(1);
    });

    test('getMe 401 maps to ServerException', () async {
      when(
        () => dio.get(any()),
      ).thenThrow(_http(401, {'message': 'Unauthorized'}));
      expect(() => ds.getMe(), throwsA(isA<ServerException>()));
    });

    test('deleteAccount sends DELETE without a body', () async {
      when(() => dio.delete(any())).thenAnswer(
        (_) async => okResponse({
          'success': true,
          'data': {'message': 'Account deleted successfully'},
        }),
      );
      await ds.deleteAccount();
      verify(() => dio.delete(ApiEndpoints.authAccount)).called(1);
    });
  });
}

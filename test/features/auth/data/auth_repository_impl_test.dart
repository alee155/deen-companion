import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repo = AuthRepositoryImpl();

  void expectNotImplemented(Result<Object?> r) {
    expect(r, isA<Error>());
    expect((r as Error).failure, isA<NotImplementedFailure>());
  }

  test('every placeholder method reports NotImplementedFailure', () async {
    expectNotImplemented(await repo.login(email: 'a@b.c', password: 'x'));
    expectNotImplemented(
      await repo.signup(name: 'n', email: 'a@b.c', password: 'x'),
    );
    expectNotImplemented(await repo.sendOtp(email: 'a@b.c'));
    expectNotImplemented(await repo.verifyOtp(email: 'a@b.c', code: '1234'));
    expectNotImplemented(await repo.resendOtp(email: 'a@b.c'));
  });
}

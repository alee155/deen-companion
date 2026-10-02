import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _Double implements UseCase<int, int> {
  @override
  Future<Result<int>> call(int params) async {
    if (params < 0) return const Error(ServerFailure('neg'));
    return Success(params * 2);
  }
}

void main() {
  test('Result.when dispatches to success branch', () {
    const Result<int> r = Success(4);
    expect(r.when(success: (d) => 'ok $d', failure: (_) => 'bad'), 'ok 4');
  });

  test('Result.when dispatches to failure branch', () {
    const Result<int> r = Error(NetworkFailure());
    final out = r.when(success: (_) => 'ok', failure: (f) => f.message);
    expect(out, const NetworkFailure().message);
  });

  test('Success can hold null-ish/empty data', () {
    const Result<List<int>> r = Success([]);
    expect(r.when(success: (d) => d.length, failure: (_) => -1), 0);
  });

  test('use case returns Success / Error', () async {
    final uc = _Double();
    final ok = await uc(3);
    expect(ok.when(success: (d) => d, failure: (_) => -1), 6);
    final bad = await uc(-1);
    expect(bad.when(success: (_) => '', failure: (f) => f.message), 'neg');
  });

  test('NoParams instances are equal', () {
    expect(NoParams(), NoParams());
    expect(NoParams().props, isEmpty);
  });
}

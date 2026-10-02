import 'package:deen_companion/core/cache/cache_first_stream_notifier.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cfg {
  String? cache;
  Result<String> result = const Success('fresh');
  int fetches = 0;
}

final _cfg = _Cfg();

class _N extends CacheFirstStreamNotifier<String> {
  @override
  String? readCache() => _cfg.cache;
  @override
  Future<Result<String>> fetchFresh() async {
    _cfg.fetches++;
    return _cfg.result;
  }
}

final _p = StreamNotifierProvider<_N, String>(_N.new);

class _FN extends FamilyCacheFirstStreamNotifier<String, int> {
  @override
  String? readCache(int arg) => arg == 1 ? 'cached$arg' : null;
  @override
  Future<Result<String>> fetchFresh(int arg) async =>
      arg == 3 ? const Error(NetworkFailure()) : Success('fresh$arg');
}

final _fp = StreamNotifierProvider.family<_FN, String, int>(_FN.new);

Future<List<AsyncValue<String>>> _collect(
  ProviderContainer c,
  ProviderListenable<AsyncValue<String>> p,
) async {
  final seen = <AsyncValue<String>>[];
  c.listen(p, (_, n) => seen.add(n), fireImmediately: true);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return seen;
}

void main() {
  late ProviderContainer c;
  setUp(() {
    _cfg
      ..cache = null
      ..result = const Success('fresh')
      ..fetches = 0;
    c = ProviderContainer();
    addTearDown(c.dispose);
  });

  group('CacheFirstStreamNotifier', () {
    test('no cache: loading then fresh', () async {
      final seen = await _collect(c, _p);
      expect(seen.first.isLoading, isTrue);
      expect(seen.last.value, 'fresh');
      expect(_cfg.fetches, 1);
    });

    test(
      'cache then different fresh: emits both without loading reset',
      () async {
        _cfg.cache = 'old';
        final seen = await _collect(c, _p);
        final values = seen
            .where((s) => s.hasValue)
            .map((s) => s.value)
            .toList();
        expect(values, ['old', 'fresh']);
        expect(seen.skip(1).any((s) => s.isLoading && !s.hasValue), isFalse);
      },
    );

    test('fresh equal to cache is not re-emitted', () async {
      _cfg.cache = 'same';
      _cfg.result = const Success('same');
      final seen = await _collect(c, _p);
      expect(seen.where((s) => s.hasValue).map((s) => s.value), ['same']);
    });

    test('failure with cache keeps cached data silently', () async {
      _cfg.cache = 'old';
      _cfg.result = const Error(NetworkFailure());
      final seen = await _collect(c, _p);
      expect(seen.any((s) => s.hasError), isFalse);
      expect(seen.last.value, 'old');
    });

    test('failure without cache surfaces the Failure as error', () async {
      _cfg.result = const Error(ServerFailure());
      final seen = await _collect(c, _p);
      expect(seen.last.hasError, isTrue);
      expect(seen.last.error, isA<ServerFailure>());
    });
  });

  group('FamilyCacheFirstStreamNotifier', () {
    test('uses per-arg cache and fresh', () async {
      final seen = await _collect(c, _fp(1));
      expect(seen.where((s) => s.hasValue).map((s) => s.value), [
        'cached1',
        'fresh1',
      ]);
    });

    test('no cache for arg -> fresh only', () async {
      final seen = await _collect(c, _fp(2));
      expect(seen.last.value, 'fresh2');
    });

    test('error without cache for arg', () async {
      final seen = await _collect(c, _fp(3));
      expect(seen.last.error, isA<NetworkFailure>());
    });
  });
}

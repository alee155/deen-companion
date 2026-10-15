import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:deen_companion/features/prayer_times/domain/prayer_times_failure.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/city_search_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/prayer_area_support.dart';

const _lahore = PrayerCity(
  name: 'Lahore',
  region: 'Punjab',
  country: 'Pakistan',
  countryCode: 'PK',
  latitude: 31.558,
  longitude: 74.3507,
  timezone: 'Asia/Karachi',
);

/// Records every query so tests can count real searches.
class _CountingRepo extends FakePrayerRepo {
  final List<String> queries = [];

  @override
  Future<Result<List<PrayerCity>>> searchCities(String query) async {
    queries.add(query);
    return citiesResult;
  }
}

void main() {
  late _CountingRepo repo;

  setUp(() {
    repo = _CountingRepo()..citiesResult = const Success([_lahore]);
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [prayerTimesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Runs [body] with a live listener and a fake clock.
  void run(void Function(ProviderContainer c, FakeAsync async) body) {
    fakeAsync((async) {
      final c = make();
      final sub = c.listen(citySearchProvider, (_, _) {});
      body(c, async);
      sub.close();
    });
  }

  CitySearchState stateOf(ProviderContainer c) => c.read(citySearchProvider);
  CitySearchController ctl(ProviderContainer c) =>
      c.read(citySearchProvider.notifier);

  test('starts idle', () {
    run((c, _) => expect(stateOf(c).status, CitySearchStatus.idle));
  });

  test('one letter is too short and does not search', () {
    run((c, async) {
      ctl(c).onQueryChanged('L');
      async.elapse(const Duration(seconds: 1));
      expect(stateOf(c).status, CitySearchStatus.tooShort);
      expect(repo.queries, isEmpty);
    });
  });

  test('waits for the debounce, then searches once', () {
    run((c, async) {
      ctl(c).onQueryChanged('La');
      expect(stateOf(c).status, CitySearchStatus.loading);
      async.elapse(const Duration(milliseconds: 399));
      expect(repo.queries, isEmpty, reason: 'still debouncing');
      async.elapse(const Duration(milliseconds: 2));
      async.flushMicrotasks();
      expect(repo.queries, ['La']);
      expect(stateOf(c).status, CitySearchStatus.results);
      expect(stateOf(c).cities, [_lahore]);
    });
  });

  test('typing on restarts the wait and only the last query is searched', () {
    run((c, async) {
      ctl(c).onQueryChanged('La');
      async.elapse(const Duration(milliseconds: 300));
      ctl(c).onQueryChanged('Lah');
      async.elapse(const Duration(milliseconds: 300));
      ctl(c).onQueryChanged('Laho');
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();
      expect(repo.queries, ['Laho']);
    });
  });

  test('the query is trimmed', () {
    run((c, async) {
      ctl(c).onQueryChanged('  Lahore  ');
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(repo.queries, ['Lahore']);
    });
  });

  test('clearing the field goes back to idle and cancels the search', () {
    run((c, async) {
      ctl(c).onQueryChanged('Lahore');
      ctl(c).onQueryChanged('');
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(stateOf(c).status, CitySearchStatus.idle);
      expect(repo.queries, isEmpty);
    });
  });

  test('no match is an empty result, not an error', () {
    repo.citiesResult = const Success([]);
    run((c, async) {
      ctl(c).onQueryChanged('Zzzz');
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(stateOf(c).status, CitySearchStatus.results);
      expect(stateOf(c).cities, isEmpty);
    });
  });

  test('the provider being down gets a friendly message', () {
    repo.citiesResult = const Error(
      PrayerTimesFailure(
        'x',
        code: PrayerTimesErrorCode.citySearchUnavailable,
        statusCode: 503,
      ),
    );
    run((c, async) {
      ctl(c).onQueryChanged('Lahore');
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(stateOf(c).status, CitySearchStatus.error);
      expect(stateOf(c).message, contains('isn’t available right now'));
    });
  });

  test('other failures show their own message, and retry searches again', () {
    repo.citiesResult = const Error(NetworkFailure());
    run((c, async) {
      ctl(c).onQueryChanged('Lahore');
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(stateOf(c).message, "You're offline. Check your connection.");

      repo.citiesResult = const Success([_lahore]);
      ctl(c).retry();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(stateOf(c).status, CitySearchStatus.results);
      expect(repo.queries, ['Lahore', 'Lahore']);
    });
  });
}

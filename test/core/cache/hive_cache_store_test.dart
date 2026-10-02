import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_storage.dart';

class _Item {
  final String name;
  final List<int> nums;
  _Item(this.name, this.nums);
  Map<String, dynamic> toJson() => {'name': name, 'nums': nums};
  static _Item fromJson(Map<String, dynamic> j) =>
      _Item(j['name'] as String, (j['nums'] as List).cast<int>());
}

void main() {
  late FakeStorage storage;
  late HiveCacheStore store;

  setUp(() {
    storage = FakeStorage();
    store = HiveCacheStore(storage);
  });

  test('read returns null on miss', () {
    expect(store.read('nope', _Item.fromJson), isNull);
  });

  test('save then read round-trips with fetchedAt close to now', () async {
    await store.save('k', _Item('a', [1, 2]), (i) => i.toJson());
    final r = store.read('k', _Item.fromJson)!;
    expect(r.data.name, 'a');
    expect(r.data.nums, [1, 2]);
    expect(DateTime.now().difference(r.fetchedAt).inSeconds, lessThan(5));
    expect(r.isStale(const Duration(minutes: 1)), isFalse);
  });

  test('save writes to the api cache box under the key', () async {
    await store.save('k', _Item('a', []), (i) => i.toJson());
    final raw = storage.get<Map>(AppConstants.apiCacheBoxName, 'k')!;
    expect(raw.keys, containsAll(['data', 'fetched_at']));
  });

  test('read deep-converts Map<dynamic,dynamic> as Hive returns', () {
    final fetched = DateTime(2024, 1, 1).toIso8601String();
    storage.boxes[AppConstants.apiCacheBoxName] = {
      'k': <dynamic, dynamic>{
        'data': <dynamic, dynamic>{
          'name': 'deep',
          'nums': <dynamic>[1, 2],
          'inner': <dynamic, dynamic>{
            'x': <dynamic>[
              <dynamic, dynamic>{'y': 1},
            ],
          },
        },
        'fetched_at': fetched,
      },
    };
    Map<String, dynamic>? seen;
    final r = store.read<String>('k', (m) {
      seen = m;
      return m['name'] as String;
    })!;
    expect(r.data, 'deep');
    expect(r.fetchedAt, DateTime(2024, 1, 1));
    expect(r.isStale(const Duration(days: 1)), isTrue);
    final inner = seen!['inner'] as Map<String, dynamic>;
    expect((inner['x'] as List).first, isA<Map<String, dynamic>>());
  });

  test('read throws on corrupt envelope (bad timestamp)', () {
    storage.boxes[AppConstants.apiCacheBoxName] = {
      'k': {'data': <String, dynamic>{}, 'fetched_at': 'garbage'},
    };
    expect(() => store.read('k', (m) => m), throwsFormatException);
  });
}

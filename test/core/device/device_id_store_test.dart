import 'dart:math';

import 'package:deen_companion/core/device/device_id_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/_support/prayer_area_support.dart';

void main() {
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('generates a version-4 UUID', () {
    for (var i = 0; i < 50; i++) {
      expect(DeviceIdStore.generate(Random(i)), matches(uuid));
    }
  });

  test('two installs do not share an id', () {
    final ids = {
      for (var i = 0; i < 100; i++) DeviceIdStore.generate(Random()),
    };
    expect(ids, hasLength(100));
  });

  test('creates once, saves, and reuses it', () async {
    final storage = PaStorage();
    final store = DeviceIdStore(storage, random: Random(1));
    final first = await store.get();
    expect(first, matches(uuid));
    expect(await store.get(), first);

    // A new process (fresh store, same storage) gets the same id back.
    final again = await DeviceIdStore(storage, random: Random(2)).get();
    expect(again, first);
  });
}

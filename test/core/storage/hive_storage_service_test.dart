import 'dart:io';

import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late HiveStorageService s;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('hive_storage_test');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  setUp(() => s = HiveStorageService());

  test('get on never-opened box returns null, getAll empty', () {
    expect(s.get<String>('unopened', 'k'), isNull);
    expect(s.getAll('unopened'), isEmpty);
  });

  test('put/get round-trip with types', () async {
    await s.put('b1', 'str', 'v');
    await s.put('b1', 'num', 2.5);
    await s.put('b1', 'flag', true);
    expect(s.get<String>('b1', 'str'), 'v');
    expect(s.get<double>('b1', 'num'), 2.5);
    expect(s.get<bool>('b1', 'flag'), isTrue);
    expect(s.get<String>('b1', 'missing'), isNull);
  });

  test('put overwrites', () async {
    await s.put('b2', 'k', 1);
    await s.put('b2', 'k', 2);
    expect(s.get<int>('b2', 'k'), 2);
  });

  test('delete removes key only', () async {
    await s.put('b3', 'a', 1);
    await s.put('b3', 'b', 2);
    await s.delete('b3', 'a');
    expect(s.get<int>('b3', 'a'), isNull);
    expect(s.get<int>('b3', 'b'), 2);
  });

  test('getAll returns string-keyed snapshot', () async {
    await s.put('b4', 'x', 1);
    await s.put('b4', 'y', 'two');
    expect(s.getAll('b4'), {'x': 1, 'y': 'two'});
  });

  test('clearAll wipes only the given box', () async {
    await s.put('b5', 'k', 1);
    await s.put('b6', 'k', 1);
    await s.clearAll('b5');
    expect(s.getAll('b5'), isEmpty);
    expect(s.get<int>('b6', 'k'), 1);
  });

  test('watch emits on put and delete', () async {
    await s.put('b7', 'seed', 0);
    var events = 0;
    final sub = s.watch('b7').listen((_) => events++);
    await s.put('b7', 'k', 1);
    await s.delete('b7', 'k');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(events, 2);
  });

  test('watch on unopened box is an empty stream', () async {
    expect(await s.watch('never').toList(), isEmpty);
  });
}

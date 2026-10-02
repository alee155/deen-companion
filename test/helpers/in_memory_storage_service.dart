import 'dart:async';

import 'package:deen_companion/core/storage/local_storage_service.dart';

/// Hand-written in-memory [LocalStorageService] for unit tests.
class InMemoryStorageService implements LocalStorageService {
  final Map<String, Map<String, dynamic>> boxes = {};
  final Map<String, StreamController<void>> _controllers = {};

  Map<String, dynamic> _box(String name) => boxes.putIfAbsent(name, () => {});

  StreamController<void> _controller(String name) =>
      _controllers.putIfAbsent(name, () => StreamController<void>.broadcast());

  @override
  Future<void> init() async {}

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    _box(boxName)[key] = value;
    _controller(boxName).add(null);
  }

  @override
  T? get<T>(String boxName, String key) => _box(boxName)[key] as T?;

  @override
  Future<void> delete(String boxName, String key) async {
    _box(boxName).remove(key);
    _controller(boxName).add(null);
  }

  @override
  Map<String, dynamic> getAll(String boxName) => Map.of(_box(boxName));

  @override
  Future<void> clearAll(String boxName) async {
    _box(boxName).clear();
    _controller(boxName).add(null);
  }

  @override
  Stream<void> watch(String boxName) => _controller(boxName).stream;
}

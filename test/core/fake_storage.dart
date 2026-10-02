import 'dart:async';

import 'package:deen_companion/core/storage/local_storage_service.dart';

/// In-memory [LocalStorageService] for tests.
class FakeStorage implements LocalStorageService {
  final Map<String, Map<String, dynamic>> boxes = {};
  final Map<String, StreamController<void>> _controllers = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    (boxes[boxName] ??= {})[key] = value;
    _controllers[boxName]?.add(null);
  }

  @override
  T? get<T>(String boxName, String key) => boxes[boxName]?[key] as T?;

  @override
  Future<void> delete(String boxName, String key) async {
    boxes[boxName]?.remove(key);
    _controllers[boxName]?.add(null);
  }

  @override
  Map<String, dynamic> getAll(String boxName) =>
      Map<String, dynamic>.from(boxes[boxName] ?? {});

  @override
  Future<void> clearAll(String boxName) async {
    boxes[boxName]?.clear();
  }

  @override
  Stream<void> watch(String boxName) =>
      (_controllers[boxName] ??= StreamController<void>.broadcast()).stream;
}

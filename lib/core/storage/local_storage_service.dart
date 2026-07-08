import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

abstract class LocalStorageService {
  Future<void> init();
  Future<void> put(String boxName, String key, dynamic value);
  T? get<T>(String boxName, String key);
  Future<void> delete(String boxName, String key);
}

class HiveStorageService implements LocalStorageService {
  final Map<String, Box> _openBoxes = {};

  static const List<String> _knownBoxes = [
    AppConstants.bookmarksBoxName,
    AppConstants.settingsBoxName,
    AppConstants.apiCacheBoxName,
  ];

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    for (final boxName in _knownBoxes) {
      _openBoxes[boxName] = await Hive.openBox(boxName);
    }
  }

  Future<Box> _requireBox(String boxName) async {
    if (_openBoxes.containsKey(boxName)) return _openBoxes[boxName]!;
    final box = await Hive.openBox(boxName);
    _openBoxes[boxName] = box;
    return box;
  }

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    final box = await _requireBox(boxName);
    await box.put(key, value);
  }

  @override
  T? get<T>(String boxName, String key) {
    final box = _openBoxes[boxName];
    return box?.get(key) as T?;
  }

  @override
  Future<void> delete(String boxName, String key) async {
    final box = await _requireBox(boxName);
    await box.delete(key);
  }
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return HiveStorageService();
});

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

abstract class LocalStorageService {
  Future<void> init();
  Future<void> put(String boxName, String key, dynamic value);
  T? get<T>(String boxName, String key);
  Future<void> delete(String boxName, String key);

  /// All key/value pairs currently stored in [boxName]. Used by features
  /// that need to read an entire collection at once (Favorites, Recent
  /// Activity) rather than a single key.
  Map<String, dynamic> getAll(String boxName);

  /// Wipes every entry in [boxName]. Used by Settings' "Clear cached
  /// content" action — scoped to a single box so it can safely target just
  /// the API response cache without touching Favorites/Recent/Settings.
  Future<void> clearAll(String boxName);

  /// Emits every time [boxName] changes (any put/delete), so a
  /// [StreamNotifier] can stay in sync with local storage reactively
  /// instead of needing every call site to remember to invalidate a
  /// provider by hand.
  Stream<void> watch(String boxName);
}

class HiveStorageService implements LocalStorageService {
  final Map<String, Box> _openBoxes = {};

  static const List<String> _knownBoxes = [
    AppConstants.bookmarksBoxName,
    AppConstants.recentActivityBoxName,
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

  @override
  Map<String, dynamic> getAll(String boxName) {
    final box = _openBoxes[boxName];
    if (box == null) return {};
    return box.toMap().map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Future<void> clearAll(String boxName) async {
    final box = await _requireBox(boxName);
    await box.clear();
  }

  @override
  Stream<void> watch(String boxName) {
    final box = _openBoxes[boxName];
    if (box == null) return const Stream.empty();
    return box.watch().map((event) => null);
  }
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return HiveStorageService();
});

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/local_storage_service.dart';
import '../utils/flow_log.dart';

/// A random id created once per install and sent as `X-Device-Id` on the
/// guest prayer-times calls. The backend rate-limits per device, so phones
/// behind one carrier address are not throttled together. It identifies the
/// installation only — never a person — and is not linked to an account.
class DeviceIdStore {
  static const _key = 'device_id';

  final LocalStorageService storage;
  final Random _random;
  String? _cached;

  DeviceIdStore(this.storage, {Random? random})
    : _random = random ?? Random.secure();

  /// The stored id, created and saved on first use.
  Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;

    final stored = storage.get<String>(AppConstants.settingsBoxName, _key);
    if (stored != null && stored.isNotEmpty) {
      FlowLog.log('DEVICE', 'DEVICE ID LOADED (${FlowLog.mask(stored)})');
      return _cached = stored;
    }

    final created = generate(_random);
    FlowLog.log('DEVICE', 'NEW DEVICE ID CREATED (${FlowLog.mask(created)})');
    await storage.put(AppConstants.settingsBoxName, _key, created);
    return _cached = created;
  }

  /// A version-4 UUID (`xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`).
  static String generate(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    String hex(int from, int to) => bytes
        .sublist(from, to)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}

final deviceIdStoreProvider = Provider<DeviceIdStore>(
  (ref) => DeviceIdStore(ref.watch(localStorageServiceProvider)),
);

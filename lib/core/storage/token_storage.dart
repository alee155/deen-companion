import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps auth tokens in the platform keystore/keychain — never in Hive, which
/// is unencrypted.
///
/// Two slots on purpose: registration hands back a token before the email is
/// verified. That token is parked as [pendingToken] and only promoted to the
/// real [accessToken] once verification succeeds, so an unverified user is
/// never treated as signed in (and the API client never sends their token).
abstract class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readPendingToken();
  Future<void> savePendingToken(String token);

  /// Stores [token] as the active access token (e.g. login of an already
  /// verified account).
  Future<void> saveAccessToken(String token);

  /// Moves the pending token into the access-token slot. Returns false when
  /// there was no pending token to promote.
  Future<bool> promotePendingToken();

  /// Drops both tokens (sign out).
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  static const _accessKey = 'auth_access_token';
  static const _pendingKey = 'auth_pending_token';

  final FlutterSecureStorage _storage;

  const SecureTokenStorage([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  ]);

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readPendingToken() => _storage.read(key: _pendingKey);

  @override
  Future<void> savePendingToken(String token) =>
      _storage.write(key: _pendingKey, value: token);

  @override
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessKey, value: token);
    await _storage.delete(key: _pendingKey);
  }

  @override
  Future<bool> promotePendingToken() async {
    final pending = await _storage.read(key: _pendingKey);
    if (pending == null || pending.isEmpty) return false;
    await _storage.write(key: _accessKey, value: pending);
    await _storage.delete(key: _pendingKey);
    return true;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _pendingKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => const SecureTokenStorage(),
);

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/api/token_store.dart';

/// Keeps the session token in the platform keystore. If the keystore is
/// unavailable (some desktops) it falls back to memory for this run only.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'carenest_token';
  String? _memory;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key) ?? _memory;
    } catch (_) {
      return _memory;
    }
  }

  @override
  Future<void> write(String token) async {
    _memory = token;
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    _memory = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

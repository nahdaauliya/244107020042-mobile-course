import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/failures.dart';

class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<void> save({required String access, required String refresh}) async {
    try {
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
    } catch (_) {
      throw const LocalFailure('Gagal menyimpan sesi login.');
    }
  }

  Future<String?> readAccess() async {
    try {
      return await _storage.read(key: _accessKey);
    } catch (_) {
      throw const LocalFailure('Gagal membaca sesi login.');
    }
  }

  Future<String?> readRefresh() async {
    try {
      return await _storage.read(key: _refreshKey);
    } catch (_) {
      throw const LocalFailure('Gagal membaca sesi login.');
    }
  }

  Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      throw const LocalFailure('Gagal menghapus sesi login.');
    }
  }
}

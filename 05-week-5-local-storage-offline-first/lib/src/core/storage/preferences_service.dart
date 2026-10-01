import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notes/domain/conflict.dart';

/// Akses ke `SharedPreferences` untuk hal kecil: **preferensi**, bukan data aplikasi.
///
/// Batasannya penting: catatan tidak pernah masuk ke sini. `SharedPreferences`
/// pada Android berarti satu file key-value yang ditulis penuh setiap kali
/// ada transaksi. Untuk daftar catatan yang perlu diurutkan dan dicari, itu
/// pilihan yang salah — makanya `NoteDatabase` memakai SQLite. Yang layak di
/// sini hanya nilai tunggal yang sering dibaca kecil: tema dan waktu terakhir
/// dibuka.
///
/// [PreferencesService] juga di-*load* sekali di `main()` lalu di-*override* ke
/// dalam `ProviderScope`. Akibatnya provider bisa jadi `Notifier` sinkron
/// (bukan `AsyncNotifier`): UI tidak pernah berkedip "loading" hanya untuk
/// membaca satu boolean, dan tidak ada race antara build pertama dan nilai
/// preferensi.
class PreferencesService {
  PreferencesService(this._prefs);

  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLastOpenedAt = 'last_opened_at';
  static const String _keyConflictStrategy = 'conflict_strategy';
  static const String _keySimulateOffline = 'simulate_offline';

  static Future<PreferencesService> load() async {
    return PreferencesService(await SharedPreferences.getInstance());
  }

  final SharedPreferences _prefs;

  SharedPreferences get raw => _prefs;

  ThemeMode readThemeMode() {
    return switch (_prefs.getString(_keyThemeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> writeThemeMode(ThemeMode mode) {
    return _prefs.setString(_keyThemeMode, mode.name);
  }

  /// Kapan aplikasi ini **terakhir dibuka** — dibaca sekali saat start, lalu
  /// ditimpa dengan waktu sekarang.
  ///
  /// Urutannya penting: yang ditampilkan adalah waktu pembukaan *sebelum*
  /// sesi ini, bukan waktu yang baru saja ditulis. Kalau dibalik, UI akan
  /// selalu menampilkan "baru saja".
  DateTime? readLastOpenedAt() {
    final raw = _prefs.getString(_keyLastOpenedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> writeLastOpenedAt(DateTime value) {
    return _prefs.setString(_keyLastOpenedAt, value.toIso8601String());
  }

  ConflictStrategy readConflictStrategy() {
    final stored = _prefs.getString(_keyConflictStrategy);
    return ConflictStrategy.values.firstWhere(
      (strategy) => strategy.name == stored,
      orElse: () => ConflictStrategy.remoteWins,
    );
  }

  Future<void> writeConflictStrategy(ConflictStrategy strategy) {
    return _prefs.setString(_keyConflictStrategy, strategy.name);
  }

  bool readSimulateOffline() => _prefs.getBool(_keySimulateOffline) ?? false;

  Future<void> writeSimulateOffline(bool value) {
    return _prefs.setBool(_keySimulateOffline, value);
  }
}

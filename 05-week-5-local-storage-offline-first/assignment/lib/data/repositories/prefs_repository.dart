import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi kecil milik aplikasi: tema dan waktu terakhir dibuka.
///
/// Dipisah dari `NoteRepository` karena sifatnya berbeda: ini konfigurasi lokal
/// yang tidak pernah ikut sinkron dan hanya dibaca satu kali saat startup.
class PrefsRepository {
  PrefsRepository([this._prefs]);

  static const String themeModeKey = 'prefs.theme_mode';
  static const String lastOpenedKey = 'prefs.last_opened_at';

  /// Injeksi instance dipakai `main()` supaya preferensi dibaca satu kali
  /// sebelum `runApp` (tema tidak akan flash).
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Tema tersimpan; nilai kosong berarti ikuti setelan sistem.
  Future<ThemeMode> readThemeMode() async {
    final prefs = await _instance;
    return switch (prefs.getString(themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> writeThemeMode(ThemeMode mode) async {
    final prefs = await _instance;
    await prefs.setString(themeModeKey, mode.name);
  }

  /// Waktu aplikasi terakhir dibuka, atau `null` bila ini pemasangan pertama.
  Future<DateTime?> readLastOpened() async {
    final prefs = await _instance;
    final raw = prefs.getString(lastOpenedKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Tandai `at` sebagai waktu dibuka terbaru.
  Future<void> writeLastOpened(DateTime at) async {
    final prefs = await _instance;
    await prefs.setString(lastOpenedKey, at.toIso8601String());
  }
}

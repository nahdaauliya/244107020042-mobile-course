import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/preferences_provider.dart';
import '../../settings/application/settings_providers.dart';
import '../data/note_database.dart';
import '../data/note_remote_source.dart';
import '../data/note_repository.dart';
import '../data/note_repository_impl.dart';
import '../domain/note.dart';
import '../domain/sync_report.dart';

// ------------------------------------------------------------------ fondasi

final noteDatabaseProvider = Provider<NoteDatabase>((ref) {
  throw UnimplementedError(
    'noteDatabaseProvider harus di-override di main() atau di test.',
  );
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// "Server" untuk demo. Mengganti ke REST API sungguhan cukup menulis
/// implementasi [NoteRemoteSource] baru — tidak ada baris lain yang berubah.
final noteRemoteSourceProvider = Provider<NoteRemoteSource>((ref) {
  return InMemoryNoteRemoteSource.demo();
});

// ---------------------------------------------------------------- repository

/// Sumber kebenaran tunggal untuk UI. Test meng-override ini dengan repository
/// palsu, sehingga tidak ada satu pun test yang perlu tahu apa-apa soal SQLite.
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepositoryImpl(
    database: ref.watch(noteDatabaseProvider),
    remote: ref.watch(noteRemoteSourceProvider),
    isOnline: () async => ref.read(isOnlineProvider),
    strategy: () => ref.read(conflictStrategyProvider),
  );
});

// --------------------------------------------------------------- connectivity

/// Status koneksi mentah dari plugin.
final connectivityProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onStatusChange();
});

/// Sumber kebenaran tunggal untuk "sedang daring atau tidak".
///
/// Menggabungkan status nyata dari [Connectivity] dengan sakelar simulasi
/// offline. `null` (plugin belum menjawab) dianggap online, supaya UI tidak
/// terjebak menampilkan "offline" selama beberapa frame pertama.
final isOnlineProvider = Provider<bool>((ref) {
  if (ref.watch(simulateOfflineProvider)) return false;
  return ref.watch(connectivityProvider).value ?? true;
});

// ---------------------------------------------------------------- daftar note

/// Daftar catatan dari cache lokal, urut `updated_at` terbaru lebih dulu.
///
/// `AsyncNotifier` dan bukan `FutureProvider` karena UI menulis lewat provider
/// yang sama; setiap mutasi lokal menulis ulang state dari database, sehingga
/// yang tampil selalu berasal dari cache, bukan dari state UI yang bisa basi.
class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() {
    return ref.watch(noteRepositoryProvider).loadNotes();
  }

  Future<Note> addNote({required String title, String body = ''}) async {
    final created = await ref
        .read(noteRepositoryProvider)
        .createNote(title: title, body: body);
    await _reload();
    return created;
  }

  Future<void> updateNote(Note note) async {
    await ref.read(noteRepositoryProvider).updateNote(note);
    await _reload();
  }

  Future<void> deleteNote(String id) async {
    await ref.read(noteRepositoryProvider).deleteNote(id);
    await _reload();
  }

  Future<void> reload() => _reload();

  Future<void> _reload() async {
    state = await AsyncValue.guard(
      () => ref.read(noteRepositoryProvider).loadNotes(),
    );
    ref.invalidate(pendingUploadCountProvider);
    ref.invalidate(cacheStatusProvider);
  }
}

final notesProvider =
    AsyncNotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);

/// Isi badge "dirty": berapa catatan yang menunggu diunggah.
final pendingUploadCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(noteRepositoryProvider).pendingUploadCount();
});

/// Status cache untuk strip status di atas daftar.
final cacheStatusProvider = FutureProvider<CacheStatus>((ref) async {
  return ref.watch(noteRepositoryProvider).cacheStatus();
});

final noteByIdProvider = FutureProvider.family<Note?, String>((ref, id) {
  return ref.watch(noteRepositoryProvider).findNote(id);
});

// ---------------------------------------------------------------------- sync

/// Laporan sinkronisasi terakhir; juga yang dibaca UI untuk menampilkan
/// ringkasan.
class SyncNotifier extends AsyncNotifier<SyncReport?> {
  @override
  Future<SyncReport?> build() async => null;

  /// Aman dipanggil saat offline: repository mengembalikan laporan "offline"
  /// alih-alih melempar exception.
  Future<SyncReport?> sync() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      return ref.read(noteRepositoryProvider).syncNotes();
    });
    state = result;
    ref.invalidate(notesProvider);
    ref.invalidate(pendingUploadCountProvider);
    ref.invalidate(cacheStatusProvider);
    return result.value;
  }
}

final syncProvider =
    AsyncNotifierProvider<SyncNotifier, SyncReport?>(SyncNotifier.new);

// ------------------------------------------------------------------- settings

/// Mode tema aktif, disimpan di `SharedPreferences`.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(preferencesServiceProvider).readThemeMode();

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(preferencesServiceProvider).writeThemeMode(mode);
  }

  /// Toggle gelap/terang.
  ///
  /// Sengaja hanya berpindah antara light dan dark, dan tidak ikut
  /// mengikuti `platformBrightness`: `Notifier` tidak punya [BuildContext], dan
  /// yang ditekan adalah tombol dengan hasil yang bisa ditebak. Ikuti sistem
  /// tersedia lewat segmented control di Pengaturan (`ThemeMode.system`).
  Future<void> toggleDark() {
    return setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Kapan aplikasi terakhir dibuka.
class LastOpenedNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => ref.read(preferencesServiceProvider).readLastOpenedAt();

  Future<void> markOpenedNow() {
    return ref.read(preferencesServiceProvider).writeLastOpenedAt(DateTime.now());
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

final lastOpenedAtProvider =
    NotifierProvider<LastOpenedNotifier, DateTime?>(LastOpenedNotifier.new);

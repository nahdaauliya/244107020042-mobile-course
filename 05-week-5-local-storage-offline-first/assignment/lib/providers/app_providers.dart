import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/note.dart';
import '../data/remote/notes_api.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/prefs_repository.dart';
import '../data/sync/sync_service.dart';

/// Retry bawaan Riverpod mencoba lagi setiap exception dengan exponential
/// backoff sampai ~38 detik. Untuk baca SQLite lokal itu mencium: kegagalannya
/// biasanya permanen (mis. `db locked` atau skema tidak cocok), bukan
/// sementara. UI lebih baik langsung menampilkan error dan menunggu pengguna
/// menekan tombol sync sendiri.
Duration? _noRetry(int retryCount, Object error) => null;

/// Sumber tunggal untuk repository catatan; dipakai list, editor, sheet
/// konflik, dan test (lewat `overrideWithValue`).
final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(),
);

/// Preferensi aplikasi: tema dan waktu terakhir dibuka.
final prefsRepositoryProvider = Provider<PrefsRepository>(
  (ref) => PrefsRepository(),
);

/// Server tiruan. Pada aplikasi nyata ini diganti implementasi `NotesApi` yang
/// memanggil REST API; antarmukanya sengaja dibuat sama supaya sinkronisasi
/// tidak ikut berubah.
final notesApiProvider = Provider<NotesApi>((ref) {
  return InMemoryNotesApi(seed: demoServerNotes());
});

/// Status jaringan, ditulis manual lewat toggle di UI.
///
/// Kenapa tidak membaca `connectivity_plus` langsung di sinkronisasi? Karena
/// "terhubung ke Wi-Fi" bukan berarti "server bisa dihubungi": perangkat yang
/// tersambung hotspot tetapi DNS-nya mati akan lolos cek konektivitas lalu
/// gagal saat request. Abstraksi ini memisahkan dua kegagalan:
/// 1. ketiadaan jaringan (mode pesawat) - nilai `false`,
/// 2. jaringan ada tapi server gagal - exception dari `NotesApi`.
///
/// Di-toggle manual juga membuat mode pesawat dapat direproduksi kapan saja,
/// termasuk di emulator dan pada tangkapan layar.
final isOnlineProvider = NotifierProvider<IsOnlineController, bool>(
  IsOnlineController.new,
);

class IsOnlineController extends Notifier<bool> {
  @override
  bool build() => true;

  void setOnline(bool value) => state = value;

  void goOffline() => setOnline(false);

  void goOnline() => setOnline(true);
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(noteRepositoryProvider),
    ref.watch(notesApiProvider),
    () => ref.read(isOnlineProvider),
  );
});

/// Tema aplikasi. Nilainya diinjeksi dari [main] supaya tidak ada satu frame
/// pun dengan warna salah saat aplikasi dibuka.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  ThemeModeController({this.initial = ThemeMode.system});

  final ThemeMode initial;

  @override
  ThemeMode build() => initial;

  /// Baca preferensi. Dipanggil sekali dari [main] sebelum `runApp`.
  Future<void> load() async {
    state = await ref.read(prefsRepositoryProvider).readThemeMode();
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(prefsRepositoryProvider).writeThemeMode(mode);
  }

  /// Ganti terang <-> gelap; dipakai tombol di AppBar.
  Future<void> toggleDark() =>
      setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

/// Waktu aplikasi terakhir dibuka, `null` pada pemasangan pertama.
final lastOpenedProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(prefsRepositoryProvider).readLastOpened(),
  retry: _noRetry,
);

/// Status proses sinkron terakhir; dibaca banner di atas daftar.
final syncRunStatusProvider =
    NotifierProvider<SyncRunStatusController, SyncRunStatus>(
      SyncRunStatusController.new,
    );

class SyncRunStatusController extends Notifier<SyncRunStatus> {
  @override
  SyncRunStatus build() {
    // Turunan dari status koneksi, jadi banner ikut rebuild saat berubah.
    ref.watch(isOnlineProvider);
    return SyncRunStatus.upToDate;
  }

  void set(SyncRunStatus value) => state = value;
}

/// Ringkasan badge: berapa yang menunggu unggah dan berapa yang konflik.
class SyncCounts {
  const SyncCounts({this.pending = 0, this.conflicted = 0});

  final int pending;
  final int conflicted;

  int get total => pending + conflicted;

  bool get isClean => total == 0;
}

/// Angka untuk badge AppBar. Dihitung ulang setiap kali daftar catatan berubah
/// supaya badge tidak pernah meleset dari isi database.
final syncCountsProvider = FutureProvider<SyncCounts>((ref) async {
  // `ref.watch` di sini yang membuat provider ikut me-rebuild saat controller
  // invalidate daftar; tanpa itu badge akan basi setelah tambah/hapus.
  ref.watch(notesControllerProvider);
  final repository = ref.watch(noteRepositoryProvider);
  final pending = await repository.countPending();
  final conflicted = await repository.countConflicted();
  return SyncCounts(pending: pending, conflicted: conflicted);
}, retry: _noRetry);

/// Catatan konflik, dipakai sheet resolusi.
final conflictedNotesProvider = FutureProvider<List<Note>>(
  (ref) => ref.watch(noteRepositoryProvider).fetchConflictedNotes(),
  retry: _noRetry,
);

/// Id konflik yang sheet-nya sudah pernah dibuka.
///
/// Tanpa ini listener akan membuka sheet berulang kali setiap kali daftar
/// konflik berubah - termasuk setiap kali pengguna menutup sheet tanpa
/// memutuskan. Menutup sheet berarti "nanti saja", jadi harus bisa dibuka lagi
/// lewat tombol di AppBar.
final announcedConflictIdsProvider =
    NotifierProvider<AnnouncedConflictsController, Set<int>>(
      AnnouncedConflictsController.new,
    );

class AnnouncedConflictsController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const <int>{};

  /// Tandai [ids] sebagai sudah diumumkan; kembalikan yang baru saja.
  Set<int> markSeen(Set<int> ids) {
    final fresh = ids.difference(state);
    state = {...state, ...ids};
    return fresh;
  }
}

/// Daftar catatan - inti dari cache-first.
///
/// `build()` hanya membaca SQLite, jadi daftar tampil seketika dan tetap utuh
/// saat offline. Penyegaran dari server **tidak** dijalankan di sini, melainkan
/// di [backgroundSyncProvider], supaya `Ref` milik notifier ini tidak dipakai
/// setelah provider dibuang (mis. karena halaman ditutup atau test selesai).
final notesControllerProvider =
    AsyncNotifierProvider<NotesController, List<Note>>(NotesController.new);

class NotesController extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() => ref.watch(syncServiceProvider).loadFromCache();

  /// Putaran penuh: tarik perubahan server, lalu dorong antrean lokal.
  /// Dipakai tombol "Sinkronkan", pull-to-refresh, dan [backgroundSyncProvider].
  Future<SyncReport> refreshFromServer() async {
    final sync = ref.read(syncServiceProvider);
    final status = ref.read(syncRunStatusProvider.notifier);

    final pull = await sync.pullAndMerge();
    if (pull.status == SyncRunStatus.offline ||
        pull.status == SyncRunStatus.failed) {
      status.set(pull.status);
      return pull;
    }

    final push = await sync.syncNotes();
    status.set(push.status);
    await _reload();
    return push;
  }

  /// Jalankan hanya antrean unggah; dipakai tombol badge dirty.
  Future<SyncReport> syncPending() async {
    final report = await ref.read(syncServiceProvider).syncNotes();
    ref.read(syncRunStatusProvider.notifier).set(report.status);
    await _reload();
    return report;
  }

  Future<Note> addNote({required String title, String body = ''}) async {
    final note = await ref
        .read(noteRepositoryProvider)
        .createNote(title: title, body: body);
    await _reload();
    return note;
  }

  Future<void> editNote(Note note) async {
    await ref.read(noteRepositoryProvider).updateNote(note);
    await _reload();
  }

  Future<void> removeNote(int id) async {
    await ref.read(noteRepositoryProvider).deleteNote(id);
    await _reload();
  }

  Future<SyncReport> keepLocalVersion(int id) async {
    final report = await ref.read(syncServiceProvider).keepLocalVersion(id);
    ref.read(syncRunStatusProvider.notifier).set(report.status);
    await _reload();
    return report;
  }

  Future<SyncReport> keepRemoteVersion(int id) async {
    final report = await ref.read(syncServiceProvider).keepRemoteVersion(id);
    ref.read(syncRunStatusProvider.notifier).set(report.status);
    await _reload();
    return report;
  }

  /// Baca ulang daftar dari SQLite. Sengaja mem-bypass invalidasi provider
  /// supaya tidak menunggu siklus rebuild Riverpod di dalam notifier.
  Future<void> _reload() async {
    state = AsyncData(await ref.read(syncServiceProvider).loadFromCache());
  }
}

/// Penyegaran server di background, dipanggil sekali saat halaman daftar
/// dibuka (`ref.watch` di `notes_page.dart`).
///
/// Dipisah dari [notesControllerProvider] supaya siklus hidupnya jelas:
/// begitu halaman ditutup, provider ini dibuang dan tidak ada operasi async
/// yang menyentuh `Ref` yang sudah mati.
final backgroundSyncProvider = FutureProvider<SyncReport>((ref) async {
  final online = ref.watch(isOnlineProvider);
  if (!online) return SyncReport.offline;

  final report = await ref
      .read(notesControllerProvider.notifier)
      .refreshFromServer();

  // Data lokal berubah karena tarikan/push: paksa UI membaca ulang.
  ref.invalidate(notesControllerProvider);
  return report;
}, retry: _noRetry);

/// Catatan contoh yang sudah ada di "server" supaya demo mode pesawat punya isi
/// yang jelas sejak aplikasi pertama dibuka.
List<Note> demoServerNotes() {
  final now = DateTime.now();
  Note make(int id, String title, String body, Duration ago) => Note(
    id: id,
    title: title,
    body: body,
    createdAt: now.subtract(ago + const Duration(hours: 4)),
    updatedAt: now.subtract(ago),
    status: SyncStatus.synced,
  );

  return [
    make(
      1,
      'Rencana Sprint 5',
      'Tuntaskan layer sinkronisasi, tulis aturan konflik, lalu buktikan dengan '
          'unit test.',
      const Duration(hours: 2),
    ),
    make(
      2,
      'Ide mode gelap',
      'Simpan ThemeMode, bukan bool, supaya pilihan "ikuti sistem" tetap '
          'mungkin.',
      const Duration(days: 1, hours: 3),
    ),
    make(
      3,
      'Cache-first itu wajib',
      'Baris ini hanya ada di SQLite. Tetap tampil saat perangkat dimatikan '
          'jaringannya - itulah bukti mode pesawat.',
      const Duration(days: 3),
    ),
  ];
}

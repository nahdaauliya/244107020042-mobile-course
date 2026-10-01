import '../domain/note.dart';
import '../domain/sync_report.dart';

/// Status cache lokal, untuk ditampilkan di UI.
class CacheStatus {
  const CacheStatus({
    required this.noteCount,
    required this.pendingUploads,
    this.lastPulledAt,
    this.lastSyncedAt,
  });

  final int noteCount;
  final int pendingUploads;
  final DateTime? lastPulledAt;
  final DateTime? lastSyncedAt;
}

/// Kontrak yang dilihat UI dan Riverpod.
///
/// Penting: UI hanya boleh bicara ke interface ini. Test menyuntik
/// implementasi palsu lewat `noteRepositoryProvider.overrideWithValue`, tanpa
/// pernah menyentuh SQLite.
abstract class NoteRepository {
  /// Baca daftar dari cache lokal. Tidak pernah menyentuh jaringan — itu
  /// syarat offline-first, bukan detail implementasi.
  Future<List<Note>> loadNotes();

  Future<Note?> findNote(String id);

  Future<Note> createNote({required String title, String body});

  /// Simpan perubahan pengguna. Mengganti `updatedAt` dan menyalakan `isDirty`.
  Future<Note> updateNote(Note note);

  Future<void> deleteNote(String id);

  Future<int> pendingUploadCount();

  Future<CacheStatus> cacheStatus();

  /// Tarik perubahan server ke cache saja, tanpa mengunggah apa pun
  /// (cache-first background refresh).
  Future<SyncReport> refreshCache();

  /// Siklus penuh: unggah antrean lokal, lalu tarik perubahan server.
  Future<SyncReport> syncNotes();
}
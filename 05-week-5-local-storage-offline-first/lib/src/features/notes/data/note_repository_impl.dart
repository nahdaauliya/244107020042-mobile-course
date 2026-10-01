import '../domain/conflict.dart';
import '../domain/note.dart';
import '../domain/remote_note.dart';
import '../domain/sync_report.dart';
import 'note_database.dart';
import 'note_remote_source.dart';
import 'note_repository.dart';

/// Implementasi offline-first.
///
/// Bentuk finally-nya:
/// * **Baca** selalu dari SQLite. Jaringan hanya dipanggil oleh
///   [refreshCache] dan [syncNotes], yang dipicu manual atau setelah app siap —
///   tidak pernah ada di critical path sebuah `build()`.
/// * **Tulis** selalu ke SQLite lebih dulu, dengan `isDirty = 1`. Pengiriman
///   adalah urusan sinkronizer, bukan urusan layar. Jadi menyimpan catatan di
///   mode pesawat tetap berhasil dan tidak pernah gagal karena timeout.
/// * `isOnline` diinjeksi, bukan dibaca langsung dari plugin, supaya test bisa
///   memaksa kondisi offline dan mode pesawat bisa disimulasikan tanpa mencabut
///   Wi-Fi.
class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({
    required NoteDatabase database,
    required this._remote,
    required this._isOnline,
    required this._strategy,
    DateTime Function()? clock,
    String Function()? idFactory,
  })  : _db = database,
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _newId = idFactory ?? generateNoteId;

  final NoteDatabase _db;
  final NoteRemoteSource _remote;
  final Future<bool> Function() _isOnline;
  final ConflictStrategy Function() _strategy;
  final DateTime Function() _clock;
  final String Function() _newId;

  @override
  Future<List<Note>> loadNotes() => _db.readVisibleNotes();

  @override
  Future<Note?> findNote(String id) => _db.findById(id);

  @override
  Future<Note> createNote({required String title, String body = ''}) {
    return _db.insert(
      Note(id: _newId(), title: title, body: body, updatedAt: _clock()),
    );
  }

  @override
  Future<Note> updateNote(Note note) async {
    final updated = note.copyWith(updatedAt: _clock(), isDirty: true);
    await _db.update(updated);
    return updated;
  }

  @override
  Future<void> deleteNote(String id) => _db.softDelete(id, at: _clock());

  @override
  Future<int> pendingUploadCount() => _db.countPendingUploads();

  @override
  Future<CacheStatus> cacheStatus() async {
    return CacheStatus(
      noteCount: await _db.countVisibleNotes(),
      pendingUploads: await _db.countPendingUploads(),
      lastPulledAt: await _readMeta(NotesSchema.keyLastPulledAt),
      lastSyncedAt: await _readMeta(NotesSchema.keyLastSyncedAt),
    );
  }

  @override
  Future<SyncReport> refreshCache() => _runSync(onlyPush: false);

  @override
  Future<SyncReport> syncNotes() => _runSync(onlyPush: true);

  Future<DateTime?> _readMeta(String key) async {
    final millis = int.tryParse(await _db.readMeta(key) ?? '');
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  /// Satu jalur untuk refresh dan sync penuh; bedanya hanya apakah antrean
  /// lokal ikut diunggah. Menggabungkan keduanya membuat urutan "push lalu
  /// pull" tidak mungkin terbalik tanpa disadari.
  Future<SyncReport> _runSync({required bool onlyPush}) async {
    final startedAt = _clock();

    // Mode pesawat: jangan coba jaringan sama sekali. Inilah yang membuat
    // `syncNotes()` aman dipanggil dari UI mana pun saat offline.
    if (!await _isOnline()) {
      return SyncReport.offline(
        startedAt: startedAt,
        pendingAfter: await _db.countPendingUploads(),
      );
    }

    final strategy = _strategy();
    final pending = onlyPush ? await _db.readPendingUploads() : <Note>[];
    final conflicts = <ConflictRecord>[];
    var pushed = 0;
    var deleted = 0;
    var pulled = 0;
    var acceptedRemote = 0;
    var keptBoth = 0;
    var failed = 0;

    // Satu fetch untuk seluruh siklus: setiap konflik diputuskan terhadap
    // snapshot yang sama, dan jaringan tidak dipanggil berulang kali.
    final List<RemoteNote> remoteSnapshot;
    try {
      remoteSnapshot = await _remote.fetchAll();
    } catch (error) {
      return SyncReport(
        startedAt: startedAt,
        reachedServer: false,
        pendingAfter: await _db.countPendingUploads(),
        error: _describe(error),
      );
    }
    final remoteById = {for (final note in remoteSnapshot) note.id: note};

    for (final local in pending) {
      final resolution = resolveConflict(
        local: local,
        remote: remoteById[local.id],
        strategy: strategy,
        idFactory: _newId,
        clock: _clock,
      );
      if (resolution.conflict != null) conflicts.add(resolution.conflict!);

      // 1. Terapkan hasil resolusi ke cache lokal lebih dulu, supaya UI
      //    konsisten walau unggahan berikutnya gagal.
      final store = resolution.localToStore;
      if (store != null) {
        if (store.id == local.id) {
          await _db.update(store);
        } else {
          await _db.insert(store);
        }
      }

      final outgoing = resolution.toPush;
      if (outgoing == null) {
        // Resolusi "pakai versi server": `localToStore` sudah bersih, jadi
        // tidak ada yang perlu diunggah.
        acceptedRemote += 1;
        continue;
      }

      // Strategi "simpan keduanya" menghasilkan catatan dengan id baru, yang
      // belum ada di SQLite — simpan dulu sebelum mengirim.
      if (outgoing.id != local.id) {
        await _db.insert(outgoing);
      }

      try {
        final stored = await _remote.push(outgoing);
        await _db.markSynced(outgoing.id, revision: stored.revision);
        if (outgoing.isDeleted) {
          deleted += 1;
        } else {
          pushed += 1;
        }
        if (resolution.decision == ConflictDecision.duplicateLocal) {
          keptBoth += 1;
        }
      } catch (_) {
        // `is_dirty` sengaja dibiarkan menyala: catatan dicoba lagi pada
        // sinkron berikutnya. Inilah yang membuat antrean tahan gangguan.
        failed += 1;
      }
    }

    // Pull: catatan server yang belum dikenal, atau yang revisinya lebih baru
    // sementara baris lokal sedang bersih. Baris dirty sudah ditangani di atas.
    final toStore = <Note>[];
    for (final remoteNote in remoteSnapshot) {
      final local = await _db.findById(remoteNote.id);
      if (local == null) {
        toStore.add(noteFromRemote(remoteNote));
        pulled += 1;
        continue;
      }
      if (local.isDirty) continue;
      if (remoteNote.revision <= local.remoteRevision) continue;
      toStore.add(noteFromRemote(remoteNote));
      pulled += 1;
    }
    await _db.upsertAll(toStore);

    final finishedAt = _clock();
    await _db.writeMeta(
      NotesSchema.keyLastPulledAt,
      finishedAt.millisecondsSinceEpoch.toString(),
    );
    if (onlyPush) {
      await _db.writeMeta(
        NotesSchema.keyLastSyncedAt,
        finishedAt.millisecondsSinceEpoch.toString(),
      );
    }

    return SyncReport(
      startedAt: startedAt,
      reachedServer: true,
      pushed: pushed,
      deleted: deleted,
      pulled: pulled,
      acceptedRemote: acceptedRemote,
      keptBoth: keptBoth,
      failed: failed,
      pendingAfter: await _db.countPendingUploads(),
      conflicts: conflicts,
    );
  }

  String _describe(Object error) {
    final text = error.toString();
    return text.length > 80 ? '${text.substring(0, 77)}...' : text;
  }
}
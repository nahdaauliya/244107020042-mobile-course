import '../local/note.dart';
import '../remote/notes_api.dart';
import '../repositories/note_repository.dart';
import 'conflict_resolver.dart';

/// Status satu putaran sinkronisasi, terpisah dari [SyncStatus] milik catatan
/// supaya "prosesnya gagal" tidak disamarkan jadi "catatannya bersih".
enum SyncRunStatus {
  /// Tidak ada jaringan: tidak ada permintaan yang dicoba.
  offline,

  /// Selesai, tidak ada perubahan di kedua sisi.
  upToDate,

  /// Selesai, ada yang berhasil dikirim atau diterima.
  completed,

  /// Ada catatan yang menunggu keputusan pengguna.
  needsDecision,

  /// Server tidak bisa dihubungi.
  failed,
}

/// Ringkasan satu putaran sinkronisasi, dipakai untuk banner dan toast.
class SyncReport {
  const SyncReport({
    required this.status,
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.message = '',
  });

  final SyncRunStatus status;

  /// Jumlah catatan yang masuk dari server (baru atau lebih baru).
  final int pulled;

  /// Jumlah catatan yang berhasil diunggah.
  final int pushed;

  /// Jumlah catatan yang ditandai konflik.
  final int conflicts;

  /// Jumlah catatan yang gagal diunggah dan tetap menunggu percobaan lagi.
  final int failed;

  final String message;

  /// `true` bila putaran ini tidak mengubah apa pun.
  bool get isNoop => pulled == 0 && pushed == 0 && conflicts == 0;

  static const SyncReport offline = SyncReport(
    status: SyncRunStatus.offline,
    message: 'Mode pesawat: sinkron ditunda, semua data dari cache lokal.',
  );
}

/// Mesin sinkronisasi.
///
/// Pembagian tanggung jawabnya sengaja dipisah agar mudah dibuktikan:
///
/// - **Baca = cache-first.** [loadFromCache] tidak pernah menyentuh jaringan;
///   daftar selalu dirender dari SQLite sehingga tampil seketika dan tetap
///   utuh saat offline. [pullAndMerge] hanya berjalan sesudahnya, di background.
/// - **Tulis = dirty flag + [syncNotes].** Setiap perubahan lokal menyalakan
///   `status = pendingUpload`, dan hanya [syncNotes] yang mengosongkan antrean.
///
/// ArgumenRepositori, API, dan pemeriksa koneksi dibuat positional supaya
/// inisialisasinya memakai initializing formals.
class SyncService {
  SyncService(
    this._repository,
    this._api,
    this._isOnline, [
    this._resolver = const ConflictResolver(),
  ]);

  final NoteRepository _repository;
  final NotesApi _api;

  /// Dijalankan sebelum setiap permintaan jaringan; inilah satu-satunya
  /// penentu apakah sinkron dicoba atau ditunda.
  final bool Function() _isOnline;
  final ConflictResolver _resolver;

  /// Cache-first: kembalikan isi lokal seketika tanpa menunggu jaringan.
  Future<List<Note>> loadFromCache() => _repository.fetchNotes();

  /// Unggah seluruh antrean lokal.
  ///
  /// Catatan yang ditandai konflik **sengaja dilewati**: mengunggah versi
  /// lokal tanpa keputusan pengguna berarti menimpa suntingan orang lain
  /// dengan buta. Antrean itu baru jalan setelah pengguna memilih lewat
  /// [keepLocalVersion].
  Future<SyncReport> syncNotes() async {
    if (!_isOnline()) return SyncReport.offline;

    final pending = await _repository.fetchPendingNotes();
    if (pending.isEmpty) {
      return const SyncReport(
        status: SyncRunStatus.upToDate,
        message: 'Tidak ada perubahan yang menunggu sinkron.',
      );
    }

    var pushed = 0;
    var conflicts = 0;
    var failed = 0;

    for (final note in pending) {
      final id = note.id;
      if (id == null) {
        failed++;
        continue;
      }
      try {
        final result = await _api.uploadNote(note);
        if (result.accepted) {
          await _repository.markSynced(id);
          pushed++;
          continue;
        }

        // Server menolak karena menyimpan versi yang lebih baru.
        final serverNote = result.serverNote;
        if (serverNote == null) {
          failed++;
          continue;
        }
        await _repository.markConflicted(
          id,
          _resolver.describe(note, serverNote),
        );
        conflicts++;
      } catch (_) {
        // Jaringan putus di tengah jalan: sisanya tetap `pendingUpload` dan
        // dicoba lagi pada putaran berikutnya.
        failed++;
      }
    }

    return SyncReport(
      status: _statusFor(pushed, conflicts, failed),
      pushed: pushed,
      conflicts: conflicts,
      failed: failed,
      message: _summarize(pushed, conflicts, failed),
    );
  }

  /// Ambil daftar dari server lalu rekonsiliasi dengan isi lokal.
  ///
  /// Dipanggil setelah [loadFromCache] supaya data lokal yang sudah tampil
  /// tidak hilang, termasuk ketika permintaan ini gagal.
  Future<SyncReport> pullAndMerge() async {
    if (!_isOnline()) return SyncReport.offline;

    final List<Note> remoteNotes;
    try {
      remoteNotes = await _api.fetchAllNotes();
    } catch (_) {
      return const SyncReport(
        status: SyncRunStatus.failed,
        message: 'Server tidak bisa dihubungi. Menampilkan cache lokal.',
      );
    }

    final localNotes = await _repository.fetchNotes();
    final localById = <int?, Note>{
      for (final note in localNotes) note.id: note,
    };

    var pulled = 0;
    var conflicts = 0;

    // Satu kali lintasan: `resolve(null, remote)` menghasilkan `pullRemote`, jadi
    // catatan yang hanya ada di server ikut tertangani di sini.
    for (final remote in remoteNotes) {
      final id = remote.id;
      if (id == null) continue;
      final local = localById[id];

      switch (_resolver.resolve(local, remote)) {
        case ConflictResolution.pullRemote:
          await _repository.applyRemote(remote);
          pulled++;
        case ConflictResolution.pushLocal:
          // Sudah ditangani oleh syncNotes(); di sini cukup diam.
          break;
        case ConflictResolution.needsUserDecision:
          await _repository.markConflicted(
            id,
            _resolver.describe(local!, remote),
          );
          conflicts++;
      }
    }

    return SyncReport(
      status: conflicts > 0
          ? SyncRunStatus.needsDecision
          : SyncRunStatus.completed,
      pulled: pulled,
      conflicts: conflicts,
      message: _summarizePull(pulled, conflicts),
    );
  }

  /// Keputusan pengguna: versi perangkat ini yang menang.
  ///
  /// Aturan last-write-wins pada server sengaja dilewati (`force: true`),
  /// karena "pakai versi ini" adalah pilihan sadar, bukan hasil tebak-tebakan
  /// jam. `updatedAt` lokal tetap dimajukan supaya daftar lokal dan server
  /// melihat urutansuntingan yang sama.
  Future<SyncReport> keepLocalVersion(int id) async {
    if (!_isOnline()) return SyncReport.offline;

    final note = await _repository.fetchNoteById(id);
    if (note == null) {
      return const SyncReport(
        status: SyncRunStatus.upToDate,
        message: 'Catatan sudah tidak ada di perangkat ini.',
      );
    }

    // `updateNote` menaikkan `updatedAt` dan mengembalikan ke antrean unggah.
    final queued = await _repository.updateNote(note);

    try {
      final result = await _api.uploadNote(queued, force: true);
      if (result.accepted) {
        await _repository.markSynced(id);
        return const SyncReport(
          status: SyncRunStatus.completed,
          pushed: 1,
          message: 'Versi perangkat ini dikirim dan menjadi rujukan.',
        );
      }
    } catch (_) {
      return const SyncReport(
        status: SyncRunStatus.failed,
        message: 'Gagal mengirim versi ini, akan dicoba lagi.',
      );
    }
    return const SyncReport(
      status: SyncRunStatus.failed,
      message: 'Server menolak versi ini.',
    );
  }

  /// Keputusan pengguna: versi server yang menang, suntingan lokal dibuang.
  Future<SyncReport> keepRemoteVersion(int id) async {
    if (!_isOnline()) return SyncReport.offline;

    final List<Note> remoteNotes;
    try {
      remoteNotes = await _api.fetchAllNotes();
    } catch (_) {
      return const SyncReport(
        status: SyncRunStatus.failed,
        message: 'Server tidak bisa dihubungi, pilihan ditunda.',
      );
    }

    final matches = remoteNotes.where((note) => note.id == id);
    if (matches.isEmpty) {
      await _repository.markSynced(id);
      return const SyncReport(
        status: SyncRunStatus.upToDate,
        message: 'Server tidak punya catatan ini lagi.',
      );
    }

    await _repository.applyRemote(matches.first);
    return SyncReport(
      status: SyncRunStatus.completed,
      pulled: 1,
      message: 'Dipakai versi dari server.',
    );
  }

  static SyncRunStatus _statusFor(int pushed, int conflicts, int failed) {
    if (failed > 0) return SyncRunStatus.failed;
    if (conflicts > 0) return SyncRunStatus.needsDecision;
    if (pushed > 0) return SyncRunStatus.completed;
    return SyncRunStatus.upToDate;
  }

  static String _summarize(int pushed, int conflicts, int failed) {
    if (pushed == 0 && conflicts == 0 && failed == 0) {
      return 'Tidak ada perubahan yang menunggu sinkron.';
    }
    final parts = <String>[
      if (pushed > 0) '$pushed catatan terkirim',
      if (conflicts > 0) '$conflicts konflik perlu diputuskan',
      if (failed > 0) '$failed gagal, akan dicoba lagi',
    ];
    return '${parts.join(', ')}.';
  }

  static String _summarizePull(int pulled, int conflicts) {
    if (pulled == 0 && conflicts == 0) return 'Data lokal sudah paling baru.';
    final parts = <String>[
      if (pulled > 0) '$pulled catatan diperbarui dari server',
      if (conflicts > 0) '$conflicts konflik terdeteksi',
    ];
    return '${parts.join(', ')}.';
  }
}

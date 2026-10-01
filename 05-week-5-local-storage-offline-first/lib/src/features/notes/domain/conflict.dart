import 'note.dart';
import 'remote_note.dart';

/// Cara aplikasi menyelesaikan ketika perangkat ini dan server sama-sama punya
/// perubahan pada catatan yang sama. Dipilih pengguna di halaman Pengaturan;
/// argumen di balik tiap opsi ada di `docs/docs_03_offline_first.md`.
enum ConflictStrategy {
  /// Terima versi server, buang perubahan lokal.
  remoteWins,

  /// Kirim ulang versi lokal apa adanya (force write).
  localWins,

  /// Simpan versi server, dan simpan juga versi lokal sebagai catatan baru.
  keepBoth;

  String get label => switch (this) {
        ConflictStrategy.remoteWins => 'Server menang',
        ConflictStrategy.localWins => 'Lokal menang',
        ConflictStrategy.keepBoth => 'Simpan keduanya',
      };

  String get description => switch (this) {
        ConflictStrategy.remoteWins =>
          'Versi server dipakai, perubahan lokal yang belum terkirim dibuang.',
        ConflictStrategy.localWins =>
          'Perubahan lokal dikirim paksa; perubahan di perangkat lain hilang.',
        ConflictStrategy.keepBoth =>
          'Tidak ada yang dibuang: versi server dipertahankan, versi lokal '
              'disimpan sebagai catatan terpisah berlabel konflik.',
      };
}

/// Keputusan sinkronizer terhadap satu catatan.
enum ConflictDecision {
  /// Tidak ada yang perlu dilakukan.
  none,

  /// Aman mengirim: server belum pernah punya, atau server tidak berubah
  /// sejak sinkron terakhir.
  push,

  /// Konflik nyata, aturan menghasilkan "pakai versi server".
  acceptRemote,

  /// Konflik nyata, versi lokal harus dikirim paksa.
  forcePush,

  /// Konflik nyata, versi server dipakai dan versi lokal jadi catatan baru.
  duplicateLocal,
}

/// Alasan konflik, dipakai laporan sinkronisasi agar keputusan bisa
/// ditelusuri kembali, bukan sekadar "terjadi konflik".
enum ConflictReason {
  /// Server punya revisi lebih baru sementara ada perubahan lokal.
  concurrentEdit,

  /// Server sudah menghapus catatan, sementara perangkat ini masih mengubah.
  remoteDeleted,

  /// Catatan lokal dihapus sementara server berubah.
  localDelete,
}

/// Satu entri laporan konflik untuk [SyncReport].
class ConflictRecord {
  const ConflictRecord({
    required this.noteId,
    required this.noteTitle,
    required this.reason,
    required this.strategy,
    required this.decision,
    required this.outcome,
  });

  final String noteId;
  final String noteTitle;
  final ConflictReason reason;
  final ConflictStrategy strategy;
  final ConflictDecision decision;

  /// Ringkasan tindakan yang benar-benar dijalankan, dalam bahasa pengguna.
  ///
  /// Disimpan per-kejadian, bukan diturunkan dari [decision] saja, karena satu
  /// keputusan bisa berarti hal berbeda tergantung [reason]: `push` adalah
  /// "kirim perubahan biasa" maupun "kirim penghapusan".
  final String outcome;

  String get reasonLabel => switch (reason) {
        ConflictReason.concurrentEdit => 'diubah di dua perangkat',
        ConflictReason.remoteDeleted => 'dihapus di server',
        ConflictReason.localDelete => 'dihapus lokal',
      };

  String get outcomeLabel => outcome;
}

/// Hasil resolusi untuk satu catatan: apa yang ditulis ke SQLite dan apa yang
/// perlu diunggah.
class ConflictResolution {
  const ConflictResolution({
    required this.decision,
    this.localToStore,
    this.toPush,
    this.conflict,
  });

  const ConflictResolution.none()
      : decision = ConflictDecision.none,
        localToStore = null,
        toPush = null,
        conflict = null;

  final ConflictDecision decision;

  /// Catatan yang harus ditulis ke SQLite setelah resolusi.
  final Note? localToStore;

  /// Catatan yang harus dikirim ke server.
  final Note? toPush;

  final ConflictRecord? conflict;

  bool get hasConflict => conflict != null;
}

/// Aturan resolusi konflik. Ini satu-satunya tempat keputusan dibuat, supaya
/// perilakunya bisa diuji dan didokumentasikan tanpa menebak.
///
/// Urutan pemeriksaan disengaja:
///
/// 1. Server belum pernah punya catatan ini → insert, tanpa konflik.
/// 2. Server tidak berubah sejak sinkron terakhir
///    (`remote.revision <= local.remoteRevision`) → fast-forward aman, kirim.
///    Ini majority case dan tidak boleh dilaporkan sebagai konflik.
/// 3. Baru kalau server berubah → konflik nyata, strategi yang dipakai.
///
/// Penghapusan menang atas perubahan dari kedua sisi, dan ini tidak bisa
/// dikonfigurasi: menghidupkan kembali catatan yang sudah sengaja dihapus
/// pengguna jauh lebih buruk daripada kehilangan satu revisi teks.
///
/// - Tombstone lokal + server berubah → kirim penghapusan lokal.
/// - Server sudah dihapus + ada perubahan lokal → terima penghapusan server,
///   sehingga catatan lokal ditandai terhapus di cache, bukan dipush balik.
ConflictResolution resolveConflict({
  required Note local,
  required RemoteNote? remote,
  required ConflictStrategy strategy,
  required String Function() idFactory,
  required DateTime Function() clock,
}) {
  final now = clock();

  // (1) Server belum tahu catatan ini: belum ada apa pun untuk bentrok.
  if (remote == null) {
    return ConflictResolution(
      decision: ConflictDecision.push,
      localToStore: local,
      toPush: local,
    );
  }

  // (2) Server tidak bergerak sejak kita terakhir sinkron.
  if (remote.revision <= local.remoteRevision) {
    return ConflictResolution(
      decision: ConflictDecision.push,
      localToStore: local,
      toPush: local,
    );
  }

  // (3) Konflik nyata.
  //
  // Penghapusan selalu menang atas perubahan, dari kedua arah. Menghidupkan lagi
  // catatan yang sudah sengaja dihapus pengguna jauh lebih buruk daripada
  // kehilangan satu revisi teks, jadi pengecualian ini tidak bisa dikonfigurasi
  // lewat [strategy] — bahkan ketika pengguna memilih "Lokal menang".
  if (local.isDeleted) {
    return ConflictResolution(
      decision: ConflictDecision.push,
      localToStore: local,
      toPush: local,
      conflict: ConflictRecord(
        noteId: local.id,
        noteTitle: local.displayTitle,
        reason: ConflictReason.localDelete,
        strategy: strategy,
        decision: ConflictDecision.push,
        outcome: 'penghapusan dikirim ke server',
      ),
    );
  }

  if (remote.deleted) {
    return ConflictResolution(
      decision: ConflictDecision.acceptRemote,
      localToStore: noteFromRemote(remote),
      conflict: ConflictRecord(
        noteId: local.id,
        noteTitle: local.displayTitle,
        reason: ConflictReason.remoteDeleted,
        strategy: strategy,
        decision: ConflictDecision.acceptRemote,
        outcome: 'penghapusan server diterima, perubahan lokal dibuang',
      ),
    );
  }

  switch (strategy) {
    case ConflictStrategy.remoteWins:
      return ConflictResolution(
        decision: ConflictDecision.acceptRemote,
        localToStore: noteFromRemote(remote),
        conflict: ConflictRecord(
          noteId: local.id,
          noteTitle: local.displayTitle,
          reason: ConflictReason.concurrentEdit,
          strategy: strategy,
          decision: ConflictDecision.acceptRemote,
          outcome: 'versi server dipakai, perubahan lokal dibuang',
        ),
      );

    case ConflictStrategy.localWins:
      return ConflictResolution(
        decision: ConflictDecision.forcePush,
        localToStore: local,
        toPush: local,
        conflict: ConflictRecord(
          noteId: local.id,
          noteTitle: local.displayTitle,
          reason: ConflictReason.concurrentEdit,
          strategy: strategy,
          decision: ConflictDecision.forcePush,
          outcome: 'versi lokal dikirim paksa, perubahan di server ditimpa',
        ),
      );

    case ConflictStrategy.keepBoth:
      final copy = Note(
        id: idFactory(),
        title: '${local.displayTitle} (konflik)',
        body: local.body,
        updatedAt: now,
        isDirty: true,
      );
      return ConflictResolution(
        decision: ConflictDecision.duplicateLocal,
        localToStore: noteFromRemote(remote),
        toPush: copy,
        conflict: ConflictRecord(
          noteId: local.id,
          noteTitle: local.displayTitle,
          reason: ConflictReason.concurrentEdit,
          strategy: strategy,
          decision: ConflictDecision.duplicateLocal,
          outcome: 'versi server dipakai, versi lokal disimpan sebagai catatan baru',
        ),
      );
  }
}

/// Bentuk catatan lokal dari salinan server saat proses pull.
Note noteFromRemote(RemoteNote remote) {
  return Note(
    id: remote.id,
    title: remote.title,
    body: remote.body,
    updatedAt: remote.updatedAt,
    isDirty: false,
    deletedAt: remote.deleted ? remote.updatedAt : null,
    remoteRevision: remote.revision,
  );
}
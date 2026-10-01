import 'conflict.dart';

/// Ringkasan satu kali siklus sinkronisasi.
///
/// Nilai objek ini yang ditampilkan ke pengguna di Snackbar/dialog, jadi
/// semua angka harus bisa dipercaya: `pushed` bertambah hanya setelah server
/// benar-benar mengonfirmasi, dan `failed` membuat `reachedServer == false`.
class SyncReport {
  const SyncReport({
    required this.startedAt,
    required this.reachedServer,
    this.pushed = 0,
    this.deleted = 0,
    this.pulled = 0,
    this.acceptedRemote = 0,
    this.keptBoth = 0,
    this.failed = 0,
    this.pendingAfter = 0,
    this.conflicts = const [],
    this.error,
  });

  /// Laporan untuk saat perangkat tidak daring: tidak ada permintaan jaringan
  /// sama sekali yang dicoba.
  const SyncReport.offline({
    required this.startedAt,
    required this.pendingAfter,
  })  : reachedServer = false,
        pushed = 0,
        deleted = 0,
        pulled = 0,
        acceptedRemote = 0,
        keptBoth = 0,
        failed = 0,
        conflicts = const [],
        error = null;

  final DateTime startedAt;

  /// `false` bila tidak ada koneksi, atau jaringan gagal di tengah jalan.
  final bool reachedServer;

  final int pushed;
  final int deleted;
  final int pulled;
  final int acceptedRemote;
  final int keptBoth;
  final int failed;

  /// Sisa antrean setelah siklus ini selesai.
  final int pendingAfter;

  final List<ConflictRecord> conflicts;
  final String? error;

  bool get hasConflicts => conflicts.isNotEmpty;

  /// `true` bila ada perubahan lokal yang masih menunggu jaringan.
  bool get hasPending => pendingAfter > 0;

  /// Ringkasan satu baris untuk UI.
  String get headline {
    if (!reachedServer) {
      return error == null
          ? 'Mode pesawat: $pendingAfter catatan menunggu sinkron'
          : 'Sinkron gagal: $error';
    }
    final parts = <String>[];
    if (pushed > 0) parts.add('$pushed dikirim');
    if (deleted > 0) parts.add('$deleted dihapus');
    if (pulled > 0) parts.add('$pulled diterima');
    if (acceptedRemote > 0) parts.add('$acceptedRemote diganti server');
    if (keptBoth > 0) parts.add('$keptBoth jadi catatan terpisah');
    if (failed > 0) parts.add('$failed gagal');
    if (parts.isEmpty) return pendingAfter > 0 ? 'Tidak ada perubahan baru' : 'Semua sudah sinkron';
    return parts.join(' · ');
  }
}
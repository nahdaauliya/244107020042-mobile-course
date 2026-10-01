import '../local/note.dart';

/// Keputusan atas satu catatan yang berubah di kedua sisi (lokal + server).
enum ConflictResolution {
  /// Tidak ada konflik: isi lokal yang dipakai, lalu diunggah.
  pushLocal,

  /// Tidak ada konflik: isi server yang dipakai, lokal diperbarui.
  pullRemote,

  /// Kedua sisi berubah dan server lebih baru. Siapkan data lokal untuk
  /// diunggah, tetapi tandai baris sebagai konflik agar pengguna memilih.
  needsUserDecision,
}

/// Aturan resolusi konflik, expressed sebagai fungsi murni agar bisa diuji
/// tanpa database dan tanpa jaringan.
///
/// Prinsip yang dipakai: **last-write-wins berdasarkan jam, dengan eskalasi ke
/// pengguna bila kedua sisi benar-benar berubah.** Alasannya ada di
/// `docs/offline_first.md`; singkatnya:
///
/// - Menang mutlak selalu (mis. "remote selalu menang") berbahaya: satu
///   perangkat yang salah jam, atau yang keliru membaca isi catatan, bisa
///   menimpa pekerjaan pengguna tanpa jejak.
/// - Menang lokal selalu juga berbahaya: dua perangkat yang sama-sama offline
///   lalu menyala akan menghasilkan dua versi berbeda tanpa ada yang menang.
/// - Karena itu: kalau hanya satu sisi yang berubah, aman untuk otomatis.
///   Kalau dua-duanya berubah, jam yang menentukan, dan hasilnya tetap
///   ditandai supaya pengguna bisa menimpa keputusannya.
class ConflictResolver {
  const ConflictResolver();

  /// Putuskan apa yang harus terjadi pada catatan [local] bila server
  /// mengirim versi [remote] untuk id yang sama.
  ///
  /// [remote] `null` berarti catatan hanya ada di server (perubahan baru dari
  /// perangkat lain) sehingga selalu diterima.
  ConflictResolution resolve(Note? local, Note? remote) {
    if (local == null) return ConflictResolution.pullRemote;
    if (remote == null) return ConflictResolution.pushLocal;

    final remoteIsNewer = remote.updatedAt.isAfter(local.updatedAt);
    final localHasChanges = local.status == SyncStatus.pendingUpload;

    // Aturan 1 - hanya server yang berubah (lokal bersih).
    if (!localHasChanges) {
      return remoteIsNewer
          ? ConflictResolution.pullRemote
          : ConflictResolution.pushLocal;
    }

    // Aturan 2 - lokal berubah, server tidak lebih baru: fast-forward.
    if (!remoteIsNewer) return ConflictResolution.pushLocal;

    // Aturan 3 - lokal berubah dan server juga lebih baru: konflik nyata.
    return ConflictResolution.needsUserDecision;
  }

  /// Potongan status lokal setelah [resolution] diterapkan.
  SyncStatus statusAfter(ConflictResolution resolution) {
    return switch (resolution) {
      ConflictResolution.pullRemote => SyncStatus.synced,
      ConflictResolution.pushLocal => SyncStatus.pendingUpload,
      ConflictResolution.needsUserDecision => SyncStatus.conflicted,
    };
  }

  /// Pesan yang ditampilkan pada badge konflik.
  String describe(Note local, Note remote) {
    return 'Server lebih baru (${_format(remote.updatedAt)}) daripada '
        'suntingan perangkat ini (${_format(local.updatedAt)}). '
        'Pilih versi yang dipakai.';
  }

  static String _format(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}

import 'dart:math';

/// Identitas lokal untuk sebuah catatan.
///
/// Meng-generated UUID-like id di perangkat sendiri, bukan id dari server,
/// supaya aplikasi tetap bisa menyimpan catatan baru saat offline. Id ini yang
/// dipakai sebagai primary key di SQLite sekaligus sebagai kunci di server
/// (lihat [docs/docs_03_offline_first.md] untuk asumsi integrasi).
String generateNoteId() {
  final random = Random.secure();
  final entropy = List<int>.generate(12, (_) => random.nextInt(256));
  final hex = entropy.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36)}-$hex';
}

/// Catatan pada domain.
///
/// Sengaja tanpa import `package:flutter/...`: kelas ini immutable murni dan
/// bisa diuji sebagai Dart biasa tanpa engine Flutter.
class Note {
  const Note({
    required this.id,
    required this.title,
    this.body = '',
    required this.updatedAt,
    this.isDirty = false,
    this.deletedAt,
    this.remoteRevision = 0,
  });

  /// Id lokal, sekaligus id di server.
  final String id;

  final String title;
  final String body;

  /// Waktu perubahan terakhir (epoch ms UTC) — dasar pengurutan daftar.
  ///
  /// Disimpan sebagai INTEGER, bukan teks ISO-8601, karena
  /// `ORDER BY updated_at DESC` adalah query utama pada halaman daftar.
  /// Kolom INTEGER bisa memakai index; kolom TEXT hanya terurut leksikografis,
  /// yang benar hanya selama formatnya persis `Z` — begitu ada offset lokal
  /// (`+07:00`) atau presisi varied, urutannya bisa salah diam-diam.
  final DateTime updatedAt;

  /// `true` bila ada perubahan lokal yang belum dikonfirmasi server.
  /// Inilah antrean sync: baris dengan `is_dirty = 1`.
  final bool isDirty;

  /// Soft delete. Bukan `null` berarti catatan sudah dihapus di perangkat ini
  /// tetapi penghapusan belum (atau belum bisa) disINKronkan.
  final DateTime? deletedAt;

  /// Revisi yang terakhir dikonfirmasi server. Dipakai untuk mendeteksi
  /// konflik: bila revisi server lebih besar, berarti ada perangkat lain yang
  /// menulis sementara perangkat ini punya perubahan lokal yang belum dikirim.
  final int remoteRevision;

  bool get isDeleted => deletedAt != null;

  /// Judul yang aman ditampilkan di UI.
  String get displayTitle {
    final trimmed = title.trim();
    return trimmed.isEmpty ? '(tanpa judul)' : trimmed;
  }

  /// Cuplikan isi untuk baris daftar.
  String get preview {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  /// Salinan dengan sebagian field diganti. `deletedAt` memakai sentinel agar
  /// nilainya bisa dikosongkan eksplisit (`clearDeletedAt`), bukan hanya
  /// "pertahankan nilai lama" seperti `copyWith` biasa.
  Note copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
    bool? isDirty,
    int? remoteRevision,
    Object? deletedAt = _keep,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      updatedAt: updatedAt ?? this.updatedAt,
      isDirty: isDirty ?? this.isDirty,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      deletedAt: identical(deletedAt, _keep) ? this.deletedAt : deletedAt as DateTime?,
    );
  }

  /// Salinan baru dengan `isDirty = true` dan `updatedAt` baru — dipakai setiap
  /// kali pengguna menyimpan, karena itu menandai "perlu diunggah".
  Note markChanged({DateTime? at}) {
    return copyWith(updatedAt: at ?? DateTime.now().toUtc(), isDirty: true);
  }

  Note markSynced({required int revision}) {
    return copyWith(isDirty: false, remoteRevision: revision);
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
      'is_dirty': isDirty ? 1 : 0,
      'deleted_at': deletedAt?.toUtc().millisecondsSinceEpoch,
      'remote_revision': remoteRevision,
    };
  }

  /// Pembacaan toleran: kolom yang hilang, `null`, atau bertipe berbeda tidak
  /// boleh membuat aplikasi crash — data lokal bisa saja berasal dari versi
  /// skema lama.
  factory Note.fromMap(Map<String, Object?> row) {
    return Note(
      id: _readString(row['id']),
      title: _readString(row['title']),
      body: _readString(row['body']),
      updatedAt: _readMillis(row['updated_at']),
      isDirty: _readInt(row['is_dirty']) != 0,
      deletedAt: _readOptionalMillis(row['deleted_at']),
      remoteRevision: _readInt(row['remote_revision']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.body == body &&
        other.updatedAt == updatedAt &&
        other.isDirty == isDirty &&
        other.deletedAt == deletedAt &&
        other.remoteRevision == remoteRevision;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, body, updatedAt, isDirty, deletedAt, remoteRevision);

  @override
  String toString() => 'Note($id, "$displayTitle", updatedAt=$updatedAt, '
      'isDirty=$isDirty, deleted=$isDeleted, rev=$remoteRevision)';
}

const Object _keep = Object();

String _readString(Object? value) => value is String ? value : '';

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime _readMillis(Object? value) {
  final millis = _readInt(value);
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}

DateTime? _readOptionalMillis(Object? value) {
  if (value == null) return null;
  final millis = _readInt(value);
  if (millis == 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
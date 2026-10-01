/// Status sinkronisasi satu catatan terhadap server.
///
/// Immutable enum supaya nilai ini bisa dibandingkan di unit test tanpa
/// menyentuh SQLite maupun jaringan.
enum SyncStatus {
  /// Sudah sama dengan versi server.
  synced,

  /// Ada perubahan lokal yang belum diunggah (kolom `dirty = 1`).
  pendingUpload,

  /// Perubahan lokal sudah terkirim, tetapi server menyorhoti versi yang
  /// berbeda. Menunggu keputusan pengguna (lihat `docs/offline_first.md`).
  conflicted,
}

/// Satu catatan.
///
/// Immutable: setiap perubahan menghasilkan objek baru lewat [copyWith], supaya
/// bisa dibandingkan dengan `==` untuk deciding konflik tanpa efek samping.
class Note {
  const Note({
    this.id,
    required this.title,
    this.body = '',
    required this.updatedAt,
    required this.createdAt,
    this.status = SyncStatus.synced,
    this.conflictNote = '',
  });

  /// Bentukkan catatan baru yang belum pernah disimpan.
  factory Note.draft({required String title, String body = '', DateTime? now}) {
    final stamp = now ?? DateTime.now();
    return Note(
      title: title,
      body: body,
      createdAt: stamp,
      updatedAt: stamp,
      status: SyncStatus.pendingUpload,
    );
  }

  /// `null` selama catatan masih draft di memori (belum masuk SQLite).
  final int? id;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Sort key utama daftar: catatan yang baru disentuh selalu di atas.
  final DateTime updatedAt;
  final SyncStatus status;

  /// Penjelasan singkat hasil resolusi konflik, ditampilkan di UI.
  final String conflictNote;

  /// `true` bila ada perubahan lokal yang belum tersinkron.
  bool get isDirty => status == SyncStatus.pendingUpload || isConflicted;

  /// `true` bila server dan lokal berbeda versi lalu harus diputuskan.
  bool get isConflicted => status == SyncStatus.conflicted;

  /// Cuplikan satu baris untuk ditampilkan di daftar.
  String get preview {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return 'Tanpa isi';
    return flat.length <= 90 ? flat : '${flat.substring(0, 90)}...';
  }

  Note copyWith({
    int? id,
    String? title,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? status,
    String? conflictNote,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      conflictNote: conflictNote ?? this.conflictNote,
    );
  }

  /// Serialisasi ke baris tabel `notes`.
  ///
  /// `updated_at` dan `created_at` disimpan sebagai epoch milliseconds (INTEGER),
  /// bukan TEXT: supaya `ORDER BY updated_at DESC` memakai index dan tidak
  /// bergantung pada format string ISO.
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'body': body,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'status': status.index,
      'conflict_note': conflictNote,
    };
  }

  /// Parsing baris `notes` ke [Note].
  ///
  /// Defensif di setiap kolom: baris bisa berasal dari skema versi lama atau
  /// dari seed, dan satu nilai rusak tidak boleh menjatuhkan seluruh daftar.
  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: (map['id'] as num?)?.toInt(),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      createdAt: _readEpoch(map['created_at']),
      updatedAt: _readEpoch(map['updated_at']),
      status: _readStatus(map['status']),
      conflictNote: map['conflict_note'] as String? ?? '',
    );
  }

  /// Versi JSON yang dikirim ke server (bukan bentuk baris SQLite).
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Bentukkan catatan dari payload server.
  ///
  /// `status` sengaja tidak ikut: itu keputusan lokal (dirty flag), bukan
  /// milik server.
  factory Note.fromJson(Map<String, Object?> json) {
    return Note(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: _readEpoch(json['created_at']),
      updatedAt: _readEpoch(json['updated_at']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.body == body &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.status == status &&
        other.conflictNote == conflictNote;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, body, createdAt, updatedAt, status, conflictNote);

  @override
  String toString() => 'Note(id: $id, title: $title, status: ${status.name})';
}

DateTime _readEpoch(Object? raw) {
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  }
  // Skema versi pertama sempat menyimpan TEXT ISO; tetap bisa dibaca.
  if (raw is String) {
    return DateTime.tryParse(raw)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

SyncStatus _readStatus(Object? raw) {
  if (raw is num) {
    final index = raw.toInt();
    if (index >= 0 && index < SyncStatus.values.length) {
      return SyncStatus.values[index];
    }
    return SyncStatus.synced;
  }
  return SyncStatus.synced;
}

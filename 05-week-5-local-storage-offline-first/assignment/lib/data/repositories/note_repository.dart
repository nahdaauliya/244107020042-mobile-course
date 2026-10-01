import 'package:sqflite/sqflite.dart';

import '../local/db.dart';
import '../local/note.dart';

/// Sumber kebenaran tunggal untuk catatan: semua baca dan tulis melewati
/// SQLite lokal, tidak pernah langsung dari UI.
///
/// Catatan penting soal bentuk datanya:
/// - Tabel `notes` adalah cache sekaligus antrean sync. Kolom `status`
///   adalah dirty flag dalam bentuk enum, bukan bool, karena ada tiga kondisi
///   (sudah sinkron / belum terunggah / konflik) - bukan dua.
/// - Kolom `id` dipakai dua kali dengan arti berbeda: primary key lokal
///   sekaligus id di server. Itu yang membuat sinkron bisa idempoten, dan
///   karena itu catatan baru harus disimpan ke lokal dulu sebelum diunggah.
class NoteRepository {
  NoteRepository({Future<Database> Function()? openDb})
    : _openDb = openDb ?? openNotesDb;

  final Future<Database> Function() _openDb;

  /// Seluruh catatan, urutan `updated_at` terbaru lebih dulu.
  Future<List<Note>> fetchNotes() async {
    final db = await _openDb();
    final rows = await db.query('notes', orderBy: 'updated_at DESC, id DESC');
    return rows.map(Note.fromMap).toList();
  }

  /// Satu catatan, atau `null` bila sudah tidak ada.
  Future<Note?> fetchNoteById(int id) async {
    final db = await _openDb();
    final rows = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Note.fromMap(rows.first);
  }

  /// Simpan catatan baru dan langsung tandai belum sinkron.
  Future<Note> createNote({required String title, String body = ''}) async {
    final db = await _openDb();
    final draft = Note.draft(title: title, body: body);
    final id = await db.insert('notes', draft.toMap());
    return draft.copyWith(id: id);
  }

  /// Perbarui isi catatan. Setiap edit menaikkan `updated_at` dan menyalakan
  /// kembali dirty flag, jadi mengedit lalu offline tidak pernah terlihat
  /// "sudah tersinkron" di server.
  Future<Note> updateNote(Note note) async {
    final db = await _openDb();
    final updated = note.copyWith(
      updatedAt: DateTime.now(),
      status: SyncStatus.pendingUpload,
      conflictNote: '',
    );
    await db.update(
      'notes',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    return updated;
  }

  Future<void> deleteNote(int id) async {
    final db = await _openDb();
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Antrean unggah: catatan yang berubah di perangkat ini dan belum dikirim.
  ///
  /// Diurutkan `updated_at` lama ke baru supaya urutan perubahan pengguna
  /// terjaga saat dipakai perangkat yang sama di beberapa titik waktu.
  Future<List<Note>> fetchPendingNotes() async {
    final db = await _openDb();
    final rows = await db.query(
      'notes',
      where: 'status = ?',
      whereArgs: [SyncStatus.pendingUpload.index],
      orderBy: 'updated_at ASC',
    );
    return rows.map(Note.fromMap).toList();
  }

  /// Catatan yang server dan lokal tidak sepakat, menunggu keputusan pengguna.
  Future<List<Note>> fetchConflictedNotes() async {
    final db = await _openDb();
    final rows = await db.query(
      'notes',
      where: 'status = ?',
      whereArgs: [SyncStatus.conflicted.index],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  /// Jumlah badge "menunggu sinkron".
  Future<int> countPending() async {
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notes WHERE status = ?',
      [SyncStatus.pendingUpload.index],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> countConflicted() async {
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notes WHERE status = ?',
      [SyncStatus.conflicted.index],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Tandai satu catatan sudah sama dengan server.
  Future<void> markSynced(int id) async {
    final db = await _openDb();
    await db.update(
      'notes',
      {'status': SyncStatus.synced.index, 'conflict_note': ''},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Catat hasil resolusi konflik supaya badge bisa menjelaskan apa yang terjadi.
  Future<void> markConflicted(int id, String message) async {
    final db = await _openDb();
    await db.update(
      'notes',
      {'status': SyncStatus.conflicted.index, 'conflict_note': message},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Terapkan versi yang diterima dari server tanpa menyentuh dirty flag lain.
  Future<void> applyRemote(Note note) async {
    final db = await _openDb();
    final id = note.id;
    if (id == null) return;
    final existing = await db.query(
      'notes',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('notes', {
        ...note.toMap(),
        'status': SyncStatus.synced.index,
        'conflict_note': '',
      });
      return;
    }
    await db.update(
      'notes',
      {
        'title': note.title,
        'body': note.body,
        'created_at': note.createdAt.millisecondsSinceEpoch,
        'updated_at': note.updatedAt.millisecondsSinceEpoch,
        'status': SyncStatus.synced.index,
        'conflict_note': '',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Kosongkan tabel. Dipakai seeding data contoh saat pertama dijalankan.
  Future<void> replaceAll(List<Note> notes) async {
    final db = await _openDb();
    await db.transaction((txn) async {
      await txn.delete('notes');
      for (final note in notes) {
        await txn.insert('notes', note.toMap());
      }
    });
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../local/db.dart';
import '../local/note.dart';

/// Sumber kebenaran tunggal untuk catatan: data dibaca dan ditulis langsung ke
/// SQLite lokal. Halaman detail memuat lewat repository ini, bukan dari state
/// halaman list, agar isinya tetap valid setelah navigasi.
class NoteRepository {
  NoteRepository({Future<Database> Function()? openDb})
      : _openDb = openDb ?? openNotesDb;

  final Future<Database> Function() _openDb;

  Future<List<Note>> fetchNotes() async {
    final db = await _openDb();
    final rows = await db.query('notes', orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  /// Ambil satu catatan berdasarkan id, atau `null` bila sudah dihapus.
  Future<Note?> fetchNoteById(int id) async {
    final db = await _openDb();
    final rows = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<Note> addNote({required String title, String body = ''}) async {
    final db = await _openDb();
    final note = Note(
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      dirty: true,
    );
    final id = await db.insert('notes', note.toMap());
    return Note(
      id: id,
      title: note.title,
      body: note.body,
      updatedAt: note.updatedAt,
      dirty: true,
    );
  }

  Future<void> updateNote(Note note) async {
    final db = await _openDb();
    await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> deleteNote(int id) async {
    final db = await _openDb();
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Antrean sync: catatan yang sudah diubah offline tapi belum terunggah.
  Future<List<Note>> fetchDirtyNotes() async {
    final db = await _openDb();
    final rows =
        await db.query('notes', where: 'dirty = 1', orderBy: 'updated_at ASC');
    return rows.map(Note.fromMap).toList();
  }

  Future<int> countDirty() async {
    final db = await _openDb();
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM notes WHERE dirty = 1');
    return ((rows.first['c'] as num?)?.toInt() ?? 0);
  }

  /// Tandai satu catatan sudah tersinkron setelah server mengonfirmasi.
  Future<void> markSynced(int id) async {
    final db = await _openDb();
    await db.update('notes', {'dirty': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllSynced() async {
    final db = await _openDb();
    await db.update('notes', {'dirty': 0}, where: 'dirty = 1');
  }
}

/// Sumber tunggal untuk repository catatan; dipakai halaman list, halaman
/// detail, dan test (lewat `overrideWithValue`).
final noteRepositoryProvider =
    Provider<NoteRepository>((ref) => NoteRepository());

/// Retry bawaan Riverpod mencoba lagi setiap `Exception` dengan exponential
/// backoff sampai ~38 detik. Untuk baca SQLite lokal itu mencium: kegagalannya
/// biasanya permanen (mis. `db locked` atau skema tidak cocok), bukan
/// sementara, sehingga UI lebih baik langsung menampilkan error dan menunggu
/// pengguna menekan refresh sendiri.
Duration? _noRetry(int retryCount, Object error) => null;

/// Daftar semua catatan, urut `updated_at DESC`.
final notesProvider = FutureProvider<List<Note>>(
  (ref) => ref.watch(noteRepositoryProvider).fetchNotes(),
  retry: _noRetry,
);

/// Jumlah catatan yang belum tersinkron.
final pendingSyncProvider = FutureProvider<int>(
  (ref) => ref.watch(noteRepositoryProvider).countDirty(),
  retry: _noRetry,
);

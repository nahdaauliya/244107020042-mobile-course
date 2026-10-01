import 'package:sqflite/sqflite.dart';

import '../domain/note.dart';

/// Nama tabel dan kunci metadata sinkronisasi, dipakai bersama oleh DAO dan
/// sinkronizer supaya tidak ada string yang diketik dua kali.
class NotesSchema {
  NotesSchema._();

  static const String notesTable = 'notes';
  static const String metaTable = 'sync_meta';
  static const int version = 1;

  static const String keyLastPulledAt = 'last_pulled_at';
  static const String keyLastSyncedAt = 'last_synced_at';
}

/// Pembuka database + pembuatan skema.
///
/// Skema Putusan:
///
/// * `updated_at`, `deleted_at` disimpan sebagai INTEGER epoch ms (lihat
///   [Note]) supaya `ORDER BY` benar dan bisa memakai index.
/// * `is_dirty` adalah flag antrean, bukan status UI. UI membaca
///   `pendingUploadCount()`; sinkronizer yang membersihkannya.
/// * `idx_notes_updated_at` melayani halaman daftar; `idx_notes_dirty_updated`
///   melayani antrean sync (`WHERE is_dirty = 1 ORDER BY updated_at`) sehingga
///   antrean diambil oldest-first dan tidak perlu sort di Dart.
class NoteDatabase {
  NoteDatabase(this._database);

  final Database _database;

  Database get raw => _database;

  static Future<NoteDatabase> open({String? path}) async {
    final databasePath = path ?? '${await getDatabasesPath()}/offline_notes.db';
    final database = await openDatabase(
      databasePath,
      version: NotesSchema.version,
      onConfigure: (db) async {
        // Wajib: SQLite aktifkan foreign_keys per-koneksi, bukan per-database.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Skema v1 adalah versi pertama yang Ships; placeholder supaya jelas
        // bahwa migrasi akan dibutuhkan begitu ada v2.
        await _createSchema(db);
      },
    );
    return NoteDatabase(database);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${NotesSchema.notesTable}(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL,
        is_dirty INTEGER NOT NULL DEFAULT 1,
        deleted_at INTEGER,
        remote_revision INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_updated_at '
      'ON ${NotesSchema.notesTable}(updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_dirty_updated '
      'ON ${NotesSchema.notesTable}(is_dirty, updated_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${NotesSchema.metaTable}(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() => _database.close();

  // ---------------------------------------------------------------- cache read

  /// Baca **cache-first**: seluruhnya dari SQLite lokal, tanpa menyentuh
  /// jaringan. Inilah yang membuat halaman daftar tetap terisi saat offline.
  ///
  /// Catatan bertanda hapus (tombstone) disembunyikan: sudah dihapus pengguna,
  /// tapi barisnya masih perlu ada untuk meneruskan penghapusan ke server.
  Future<List<Note>> readVisibleNotes() async {
    final rows = await _database.query(
      NotesSchema.notesTable,
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> findById(String id) async {
    final rows = await _database.query(
      NotesSchema.notesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  // -------------------------------------------------------------------- writes

  /// Insert catatan baru. Selalu `isDirty = 1`: tidak ada alasan untuk menyimpan
  /// catatan lokal yang belum pernah sampai di server.
  Future<Note> insert(Note note) async {
    final dirty = note.copyWith(isDirty: true);
    await _database.insert(
      NotesSchema.notesTable,
      dirty.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return dirty;
  }

  Future<void> update(Note note) async {
    await _database.update(
      NotesSchema.notesTable,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  /// Soft delete: baris tetap ada dengan `deleted_at` terisi dan `is_dirty = 1`
  /// supaya penghapusan ikut masuk antrean sinkron.
  Future<void> softDelete(String id, {DateTime? at}) async {
    await _database.update(
      NotesSchema.notesTable,
      {
        'deleted_at': (at ?? DateTime.now().toUtc()).toUtc().millisecondsSinceEpoch,
        'updated_at': (at ?? DateTime.now().toUtc()).toUtc().millisecondsSinceEpoch,
        'is_dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Tulis banyak baris dalam satu transaksi. Dipakai pull sinkronisasi supaya
  /// cache tidak pernah terlihat setengah terisi.
  Future<void> upsertAll(List<Note> notes) async {
    if (notes.isEmpty) return;
    await _database.transaction((txn) async {
      final batch = txn.batch();
      for (final note in notes) {
        batch.insert(
          NotesSchema.notesTable,
          note.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> markSynced(String id, {required int revision}) async {
    await _database.update(
      NotesSchema.notesTable,
      {'is_dirty': 0, 'remote_revision': revision},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------- sync queue

  /// Antrean unggah: semua baris `is_dirty = 1`, **oldest first**.
  ///
  /// Urutan ascension disengaja. Bila sinkron terputus di tengah, catatan yang
  /// lebih lama sudah lebih dulu sampai server, jadi penulisan terakhir yang
  /// played paling dekat dengan keadaan server.
  Future<List<Note>> readPendingUploads() async {
    final rows = await _database.query(
      NotesSchema.notesTable,
      where: 'is_dirty = 1',
      orderBy: 'updated_at ASC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<int> countPendingUploads() async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS total FROM ${NotesSchema.notesTable} WHERE is_dirty = 1',
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> countVisibleNotes() async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS total FROM ${NotesSchema.notesTable} '
      'WHERE deleted_at IS NULL',
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  // --------------------------------------------------------------------- meta

  Future<void> writeMeta(String key, String value) async {
    await _database.insert(
      NotesSchema.metaTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> readMeta(String key) async {
    final rows = await _database.query(
      NotesSchema.metaTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }
}
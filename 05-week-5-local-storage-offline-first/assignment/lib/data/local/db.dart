import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const String notesDatabaseName = 'offline_notes.db';

const int notesDatabaseVersion = 1;

/// Buka (dan bila perlu buat) database catatan.
///
/// Diekspos sebagai fungsi biasa, bukan `final db = openNotesDb()`, supaya
/// repository bisa diuji dengan objek fake lewat parameter `openDb`.
Future<Database> openNotesDb() async {
  final dir = await getDatabasesPath();
  return openDatabase(
    p.join(dir, notesDatabaseName),
    version: notesDatabaseVersion,
    onConfigure: (db) async {
      // Hanya perlu diaktifkan bila nanti ada tabel yang memakai foreign key.
      await db.execute('PRAGMA foreign_keys = ON');
    },
    onCreate: (db, version) async {
      await createNotesSchema(db);
    },
  );
}

/// Buat skema awal. Dipisah dari [openNotesDb] agar bisa dipanggil ulang,
/// misalnya dari seeding data contoh pada proses pertama.
Future<void> createNotesSchema(Database db) async {
  await db.execute('''
    CREATE TABLE notes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      body TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      status INTEGER NOT NULL DEFAULT 0,
      conflict_note TEXT NOT NULL DEFAULT ''
    )
  ''');

  // Sort key daftar: "yang baru diedit selalu di atas".
  await db.execute('CREATE INDEX idx_notes_updated ON notes(updated_at DESC)');
  // Antrean sync jadi O(jumlah dirty), bukan O(total catatan).
  await db.execute('CREATE INDEX idx_notes_status ON notes(status)');
}

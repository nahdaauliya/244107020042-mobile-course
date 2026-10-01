import 'package:sqflite/sqflite.dart';
import 'local/db.dart';
import 'repositories/note_repository.dart';

/// Satu post yang disimpan di tabel `cached_posts` (payload disimpan sebagai
/// teks; di project nyata payload ini JSON hasil decode response API).
class Post {
  const Post({required this.id, required this.title});

  final int id;
  final String title;

  factory Post.fromMap(Map<String, Object?> map) => Post(
        id: (map['id'] as num?)?.toInt() ?? 0,
        title: map['payload'] as String? ?? '',
      );
}

/// Baca cache post dari tabel `cached_posts`, terbaru lebih dulu.
Future<List<Post>> readCachedPosts({
  Future<Database> Function()? openDb,
}) async {
  final db = await (openDb ?? openNotesDb)();
  final rows = await db.query('cached_posts', orderBy: 'cached_at DESC');
  return rows.map(Post.fromMap).toList();
}

/// Tulis hasil fetch terbaru ke cache (ganti seluruh isi).
Future<void> writeCachedPosts(
  List<Post> posts, {
  Future<Database> Function()? openDb,
}) async {
  final db = await (openDb ?? openNotesDb)();
  final batch = db.batch();
  batch.delete('cached_posts');
  final now = DateTime.now().toIso8601String();
  for (final post in posts) {
    batch.insert('cached_posts', {
      'id': post.id,
      'payload': post.title,
      'cached_at': now,
    });
  }
  await batch.commit(noResult: true);
}

/// Segarkan cache di background lalu panggil `onRefreshed` supaya UI bisa
/// invalidate provider-nya. Error diabaikan: cache lama tetap dipakai.
void refreshPostsInBackground({
  required Future<List<Post>> Function() fetchRemote,
  required void Function(List<Post> posts) onRefreshed,
  bool Function()? isCancelled,
  Future<Database> Function()? openDb,
}) {
  final cancelled = isCancelled ?? () => false;
  Future<void>(() async {
    try {
      final fresh = await fetchRemote();
      if (cancelled()) return;
      await writeCachedPosts(fresh, openDb: openDb);
      onRefreshed(fresh);
    } catch (_) {
      // Offline atau server gagal: pertahankan cache yang ada.
    }
  });
}

/// Cache-first: kembalikan cache seketika agar UI tidak blank saat offline,
/// lalu segarkan dari jaringan di background.
Future<List<Post>> loadPostsCacheFirst({
  required Future<List<Post>> Function() fetchRemote,
  required void Function(List<Post> posts) onRefreshed,
  bool Function()? isCancelled,
  Future<Database> Function()? openDb,
}) async {
  final db = openDb;
  final cached = await readCachedPosts(openDb: db);
  refreshPostsInBackground(
    fetchRemote: fetchRemote,
    onRefreshed: onRefreshed,
    isCancelled: isCancelled,
    openDb: db,
  );
  return cached;
}

/// Sinkronisasi catatan lokal ke server, memakai flag `dirty` pada tabel
/// `notes` sebagai antrean: setiap catatan yang diubah offline ditandai
/// `dirty = 1`, lalu ditandai bersih setelah server mengonfirmasi.
///
/// Mengembalikan jumlah catatan yang berhasil tersinkron. Catatan yang gagal
/// tetap `dirty` sehingga dicoba lagi pada sinkron berikutnya.
Future<int> syncNotes(
  NoteRepository repo, {
  Future<bool> Function(int id)? uploadNote,
}) async {
  final upload = uploadNote ?? _simulateUpload;

  final dirtyNotes = await repo.fetchDirtyNotes();
  if (dirtyNotes.isEmpty) return 0;

  var synced = 0;
  for (final note in dirtyNotes) {
    final id = note.id;
    if (id == null) continue;
    try {
      if (!await upload(id)) continue;
      await repo.markSynced(id);
      synced++;
    } catch (_) {
      // Biarkan catatan tetap dirty untuk percobaan berikutnya.
    }
  }
  return synced;
}

/// Placeholder: pada project nyata, kirim catatan `id` ke REST API di sini
/// dan kembalikan `true` bila server menjawab 2xx.
Future<bool> _simulateUpload(int id) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return true;
}

/// Jumlah catatan yang masih menunggu sinkron.
Future<int> pendingSyncCount(NoteRepository repo) => repo.countDirty();

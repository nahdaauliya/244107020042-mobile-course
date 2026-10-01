import 'package:offline_notes/data/local/note.dart';
import 'package:offline_notes/data/remote/notes_api.dart';
import 'package:offline_notes/data/repositories/note_repository.dart';

/// Repository palsu untuk test: seluruh data hidup di dalam [Map], tidak
/// pernah menyentuh SQLite maupun jaringan.
///
/// Dipakai lewat `overrideWithValue` pada `noteRepositoryProvider` supaya
/// logika provider bisa diuji tanpa database. Yang bisa dikontrol:
/// - [failOnRead] / [failOnWrite] untuk menguji jalur error,
/// - [readCount] / [writeCount] untuk membuktikan tidak ada akses berlebihan.
class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository([List<Note>? initial]) {
    for (final note in initial ?? const <Note>[]) {
      final id = note.id;
      if (id != null) _notes[id] = note;
    }
    if (_notes.isEmpty) {
      _nextId = 1;
    } else {
      _nextId = _notes.keys.reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  final Map<int, Note> _notes = {};
  late int _nextId;

  /// Menaruh catatan apa adanya, termasuk `updatedAt` dan `status` yang sudah
  /// ditentukan test. `createNote`/`updateNote` selalu memakai jam sekarang
  /// sehingga tidak bisa dipakai untuk menyusun skenario konflik.
  void seed(Note note) {
    final id = note.id;
    if (id == null) return;
    _notes[id] = note;
    if (id >= _nextId) _nextId = id + 1;
  }

  /// Melempar error pada setiap baca, untuk menguji state error di UI.
  Object? failOnRead;

  /// Melempar error pada setiap tulis.
  Object? failOnWrite;

  int readCount = 0;
  int writeCount = 0;

  @override
  Future<List<Note>> fetchNotes() async {
    readCount++;
    if (failOnRead != null) throw failOnRead!;
    return _sorted();
  }

  @override
  Future<Note?> fetchNoteById(int id) async {
    readCount++;
    if (failOnRead != null) throw failOnRead!;
    return _notes[id];
  }

  @override
  Future<Note> createNote({required String title, String body = ''}) async {
    writeCount++;
    if (failOnWrite != null) throw failOnWrite!;
    final note = Note.draft(title: title, body: body).copyWith(id: _nextId++);
    _notes[note.id!] = note;
    return note;
  }

  @override
  Future<Note> updateNote(Note note) async {
    writeCount++;
    if (failOnWrite != null) throw failOnWrite!;
    final id = note.id;
    if (id == null) return note;
    final updated = note.copyWith(
      updatedAt: DateTime.now(),
      status: SyncStatus.pendingUpload,
      conflictNote: '',
    );
    _notes[id] = updated;
    return updated;
  }

  @override
  Future<void> deleteNote(int id) async {
    writeCount++;
    if (failOnWrite != null) throw failOnWrite!;
    _notes.remove(id);
  }

  @override
  Future<List<Note>> fetchPendingNotes() async {
    readCount++;
    if (failOnRead != null) throw failOnRead!;
    return _notes.values
        .where((note) => note.status == SyncStatus.pendingUpload)
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  }

  @override
  Future<List<Note>> fetchConflictedNotes() async {
    readCount++;
    if (failOnRead != null) throw failOnRead!;
    return _notes.values
        .where((note) => note.status == SyncStatus.conflicted)
        .toList();
  }

  @override
  Future<int> countPending() async => _notes.values
      .where((note) => note.status == SyncStatus.pendingUpload)
      .length;

  @override
  Future<int> countConflicted() async => _notes.values
      .where((note) => note.status == SyncStatus.conflicted)
      .length;

  @override
  Future<void> markSynced(int id) async {
    writeCount++;
    final note = _notes[id];
    if (note == null) return;
    _notes[id] = note.copyWith(status: SyncStatus.synced, conflictNote: '');
  }

  @override
  Future<void> markConflicted(int id, String message) async {
    writeCount++;
    final note = _notes[id];
    if (note == null) return;
    _notes[id] = note.copyWith(
      status: SyncStatus.conflicted,
      conflictNote: message,
    );
  }

  @override
  Future<void> applyRemote(Note note) async {
    writeCount++;
    final id = note.id;
    if (id == null) return;
    _notes[id] = note.copyWith(status: SyncStatus.synced, conflictNote: '');
  }

  @override
  Future<void> replaceAll(List<Note> notes) async {
    writeCount++;
    _notes.clear();
    for (final note in notes) {
      final id = note.id;
      if (id != null) _notes[id] = note;
    }
  }

  /// Urutan yang sama dengan `ORDER BY updated_at DESC, id DESC` di SQLite.
  List<Note> _sorted() {
    return _notes.values.toList()..sort((a, b) {
      final byTime = b.updatedAt.compareTo(a.updatedAt);
      return byTime != 0 ? byTime : (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }
}

/// Server palsu: selalu gagal. Dipakai untuk menguji bahwa UI tetap
/// menampilkan cache lokal ketika jaringan ada tapi server tidak merespons.
class AlwaysFailingNotesApi implements NotesApi {
  AlwaysFailingNotesApi([this.error = 'Server tidak merespons']);

  final Object error;

  int fetchAttempts = 0;

  @override
  Future<List<Note>> fetchAllNotes() async {
    fetchAttempts++;
    throw error;
  }

  @override
  Future<UploadResult> uploadNote(Note note, {bool force = false}) async =>
      throw error;

  @override
  Future<void> deleteNote(int id) async => throw error;
}

/// Server palsu tanpa latensi, diisi dari daftar catatan.
///
/// Meniru aturan last-write-wins yang sama dengan `InMemoryNotesApi` supaya
/// skenario konflik bisa diuji tanpa menunggu waktu.
class ImmediateNotesApi implements NotesApi {
  ImmediateNotesApi([List<Note>? seed]) {
    for (final note in seed ?? const <Note>[]) {
      final id = note.id;
      if (id != null) _store[id] = note;
    }
  }

  final Map<int, Note> _store = {};

  List<Note> get serverNotes => _store.values.toList();

  @override
  Future<List<Note>> fetchAllNotes() async => _store.values.toList();

  @override
  Future<UploadResult> uploadNote(Note note, {bool force = false}) async {
    final id = note.id;
    if (id == null) return const UploadResult(accepted: false);
    final current = _store[id];
    if (!force &&
        current != null &&
        current.updatedAt.isAfter(note.updatedAt)) {
      return UploadResult(accepted: false, serverNote: current);
    }
    _store[id] = note.copyWith(status: SyncStatus.synced);
    return UploadResult(accepted: true, serverNote: _store[id]);
  }

  @override
  Future<void> deleteNote(int id) async {
    _store.remove(id);
  }
}

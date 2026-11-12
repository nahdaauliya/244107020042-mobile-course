import '../core/failures.dart';
import '../features/notes/domain/entities/note.dart';
import '../features/notes/domain/repositories/note_repository.dart';

/// Repository deterministik untuk profiling.
///
/// Data dibuat di memori agar harness bisa berjalan di Chrome tanpa SQLite
/// atau backend. Jumlah dan ukuran catatan dibuat tetap supaya hasil baseline
/// bisa dibandingkan antar-run.
class PerfSeedNoteRepository implements NoteRepository {
  PerfSeedNoteRepository({this.count = 500})
    : _notes = List.generate(count, _buildNote) {
    _nextId = count + 1;
  }

  final int count;
  final List<Note> _notes;
  late int _nextId;

  static const List<String> _topics = [
    'Algoritma dan Struktur Data',
    'Basis Data Lanjut',
    'Pemrograman Mobile',
    'Jaringan Komputer',
    'Kecerdasan Buatan',
    'Sistem Operasi',
    'Rekayasa Perangkat Lunak',
    'Keamanan Informasi',
  ];

  static Note _buildNote(int index) {
    final topic = _topics[index % _topics.length];
    final body =
        'Ringkasan materi $topic pertemuan ${index + 1}. '
        'Catatan ini berisi poin utama, tugas, dan referensi yang perlu '
        'dibaca sebelum sesi berikutnya. '
        'Gunakan catatan ini untuk menyiapkan diskusi kelompok dan kuis.';

    return Note(
      id: index + 1,
      title: 'Catatan ${index + 1}: $topic',
      body: body,
      updatedAt: DateTime(2026, 11, 11, 8).subtract(Duration(minutes: index)),
    );
  }

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    return (notes: List<Note>.unmodifiable(_notes), failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    final note = Note(
      id: _nextId++,
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      dirty: true,
    );
    _notes.insert(0, note);
    return (note: note, failure: null);
  }
}

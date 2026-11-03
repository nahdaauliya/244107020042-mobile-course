import '../entities/note.dart';

/// Aturan pencarian notes berdasarkan judul.
/// Murni Dart: tidak tahu Flutter, SQLite, atau Dio.
class SearchNotes {
  const SearchNotes();

  List<Note> call(List<Note> notes, String query) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return notes;
    return notes
        .where((note) => note.title.toLowerCase().contains(keyword))
        .toList();
  }
}

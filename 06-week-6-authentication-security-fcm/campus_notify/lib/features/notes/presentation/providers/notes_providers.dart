import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/add_note.dart';
import '../../domain/usecases/get_notes.dart';
import '../../domain/usecases/search_notes.dart';

// Di-override di composition root (main.dart) agar presentation tidak
// mengimpor layer data.
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  throw UnimplementedError('noteRepositoryProvider belum di-override');
});

// Domain layer: use case menerima abstraksi, bukan implementasi.
final getNotesProvider = Provider<GetNotes>((ref) {
  return GetNotes(ref.watch(noteRepositoryProvider));
});

final addNoteProvider = Provider<AddNote>((ref) {
  return AddNote(ref.watch(noteRepositoryProvider));
});

// Presentation layer: state untuk UI.
final notesProvider = AsyncNotifierProvider<NotesNotifier, List<Note>>(
  NotesNotifier.new,
);

// Pencarian judul: kata kunci berubah real-time saat pengguna mengetik.
final notesSearchQueryProvider =
    NotifierProvider<NotesSearchQueryNotifier, String>(
  NotesSearchQueryNotifier.new,
);

class NotesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

// Daftar catatan yang sudah difilter oleh use case domain.
final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final query = ref.watch(notesSearchQueryProvider);
  return ref.watch(notesProvider).whenData(
        (notes) => const SearchNotes().call(notes, query),
      );
});

/// Kegagalan baca SQLite lokal biasanya permanen; jangan retry otomatis.
Duration? _noRetry(int retryCount, Object error) => null;

class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final result = await ref.watch(getNotesProvider).call();
    final failure = result.failure;
    if (failure != null) throw Exception(failure.message);
    return result.notes;
  }

  Future<void> add({required String title, String body = ''}) async {
    final result = await ref.read(addNoteProvider).call(title: title, body: body);
    final failure = result.failure;
    if (failure != null) throw Exception(failure.message);
    ref.invalidateSelf();
  }
}

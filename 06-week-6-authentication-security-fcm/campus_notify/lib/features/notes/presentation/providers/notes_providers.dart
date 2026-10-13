import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/note_repository_impl.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/add_note.dart';
import '../../domain/usecases/get_notes.dart';

// Data layer: opener database disuntikkan (mudah diganti fake saat test).
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepositoryImpl(openDb: openNotesDb);
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
  retry: _noRetry,
);

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

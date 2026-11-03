import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/notes/domain/entities/note.dart';
import 'package:campus_notify/features/notes/domain/repositories/note_repository.dart';
import 'package:campus_notify/features/notes/presentation/pages/notes_page.dart';
import 'package:campus_notify/features/notes/presentation/providers/notes_providers.dart';

class _EmptyRepo implements NoteRepository {
  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async =>
      (notes: const <Note>[], failure: null);

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async =>
      (note: null, failure: null);
}

void main() {
  testWidgets(
    'tanpa notes, query apa pun tetap tampilkan empty state awal',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [noteRepositoryProvider.overrideWithValue(_EmptyRepo())],
          child: const MaterialApp(home: NotesPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ujian');
      await tester.pump();

      expect(find.text('Belum ada catatan.'), findsOneWidget);
      expect(
        find.text('Tidak ada catatan dengan judul "ujian".'),
        findsNothing,
      );
    },
  );
}

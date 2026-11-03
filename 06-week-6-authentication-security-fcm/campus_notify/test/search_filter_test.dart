import 'package:flutter_test/flutter_test.dart';

import 'package:campus_notify/features/notes/domain/entities/note.dart';
import 'package:campus_notify/features/notes/domain/usecases/search_notes.dart';

Note _note(String title) =>
    Note(title: title, updatedAt: DateTime(2026, 11, 1));

void main() {
  const search = SearchNotes();
  final list = [
    _note('Belanja bulanan'),
    _note('Belanja kampus'),
    _note('Rapat kampus'),
  ];

  test('filter abaikan huruf besar/kecil', () {
    expect(
      search(list, 'BELANJA').map((n) => n.title),
      ['Belanja bulanan', 'Belanja kampus'],
    );
  });

  test('query tak cocok kembalikan kosong', () {
    expect(search(list, 'zzz-tak-ada'), isEmpty);
  });

  test('query kosong menampilkan semua catatan', () {
    expect(search(list, '').map((n) => n.title), [
      'Belanja bulanan',
      'Belanja kampus',
      'Rapat kampus',
    ]);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_notes/data/local/note.dart';

/// Unit test model [Note] - tanpa database, tanpa widget, tanpa jaringan.
void main() {
  group('Note.toMap / Note.fromMap', () {
    test('mengubah waktu ke epoch milliseconds agar bisa diurutkan di SQL', () {
      final note = Note(
        id: 7,
        title: 'Rencana',
        body: 'isi',
        createdAt: DateTime(2026, 3, 1, 8),
        updatedAt: DateTime(2026, 3, 2, 9, 30),
        status: SyncStatus.pendingUpload,
      );

      final map = note.toMap();

      expect(map['id'], 7);
      expect(map['title'], 'Rencana');
      expect(
        map['updated_at'],
        DateTime(2026, 3, 2, 9, 30).millisecondsSinceEpoch,
      );
      expect(map['created_at'], DateTime(2026, 3, 1, 8).millisecondsSinceEpoch);
      expect(map['status'], SyncStatus.pendingUpload.index);
    });

    test('fromMap mengembalikan objek yang sama dengan aslinya', () {
      final note = Note(
        id: 12,
        title: 'Cache-first',
        body: 'baris/body',
        createdAt: DateTime(2026, 5, 1, 7),
        updatedAt: DateTime(2026, 5, 2, 10, 15),
        status: SyncStatus.conflicted,
        conflictNote: 'Server lebih baru',
      );

      final restored = Note.fromMap(note.toMap());

      expect(restored, note);
      expect(restored.hashCode, note.hashCode);
      expect(restored.isConflicted, isTrue);
      expect(restored.isDirty, isTrue);
    });

    test('kolom yang rusak tidak menjatuhkan seluruh catatan', () {
      final restored = Note.fromMap(const {
        'id': 3,
        'title': 'Tanpa kolom waktu',
        'body': null,
        'updated_at': 'bukan angka',
        'status': 99,
      });

      expect(restored.id, 3);
      expect(restored.body, '');
      expect(restored.status, SyncStatus.synced);
      expect(restored.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('Status sinkron', () {
    test('draft langsung berstatus pendingUpload', () {
      final draft = Note.draft(title: 'Baru', now: DateTime(2026, 1, 1));

      expect(draft.id, isNull);
      expect(draft.isDirty, isTrue);
      expect(draft.isConflicted, isFalse);
      expect(draft.updatedAt, draft.createdAt);
    });

    test('catatan tersinkron tidak berstatus dirty', () {
      final note = Note(
        title: 'A',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(note.isDirty, isFalse);
    });

    test('copyWith tidak mengubah field yang tidak disebut', () {
      final note = Note(
        id: 4,
        title: 'Judul',
        body: 'Isi',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      final renamed = note.copyWith(title: 'Judul baru');

      expect(renamed.id, 4);
      expect(renamed.body, 'Isi');
      expect(renamed.updatedAt, note.updatedAt);
      expect(renamed.title, 'Judul baru');
    });
  });

  group('Cuplikan isi', () {
    test('isi kosong memakai teks pengganti', () {
      final note = Note(
        title: 'Kosong',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(note.preview, 'Tanpa isi');
    });

    test('baris baru diratakan dan dipotong pada 90 karakter', () {
      final note = Note(
        title: 'Panjang',
        body: '  baris pertama\nbaris kedua  ',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(note.preview, 'baris pertama baris kedua');

      final long = note.copyWith(body: 'x' * 200);
      expect(long.preview.length, 93);
      expect(long.preview.endsWith('...'), isTrue);
    });
  });
}

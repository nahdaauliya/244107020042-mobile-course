import 'package:ai_challenge/src/features/notes/domain/note.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit test untuk model [Note].
///
/// Fokusnya bukan "model bisa dibuat", melainkan dua hal yang paling mudah
/// rusak diam-diam di aplikasi offline: serialisasi ke SQLite dan pembacaan
/// dari baris yang tidak lengkap.
void main() {
  final sample = DateTime.utc(2026, 3, 14, 9, 26, 53, 123);
  final sampleMillis = sample.millisecondsSinceEpoch;

  group('toMap', () {
    test('menyimpan updated_at sebagai epoch ms UTC, bukan teks ISO', () {
      final map = Note(
        id: 'n1',
        title: 'Belajar sqflite',
        updatedAt: sample,
      ).toMap();

      expect(map['updated_at'], sampleMillis);
      expect(map['updated_at'], isA<int>());
      // Epoch ms harus menunjuk waktu yang sama lagi setelah dibaca ulang.
      final roundTrip = Note.fromMap(map);
      expect(roundTrip.updatedAt.millisecondsSinceEpoch, sampleMillis);
      expect(roundTrip.updatedAt, sample, reason: 'harus kembali sebagai UTC');
    });

    test('waktu lokal dikonversi ke UTC sebelum disimpan', () {
      final map = Note(
        id: 'n1',
        title: 'x',
        updatedAt: sample.toLocal(),
      ).toMap();

      expect(map['updated_at'], sampleMillis);
    });

    test('is_dirty dan deleted_at ditulis sebagai INTEGER atau null', () {
      final map = Note(
        id: 'n1',
        title: 'x',
        updatedAt: sample,
        isDirty: true,
      ).toMap();

      expect(map['is_dirty'], 1);
      expect(map['deleted_at'], isNull);

      final tombstone = Note(
        id: 'n1',
        title: 'x',
        updatedAt: sample,
        deletedAt: sample,
      ).toMap();

      expect(tombstone['is_dirty'], 0);
      expect(tombstone['deleted_at'], sampleMillis);
    });
  });

  group('fromMap', () {
    test('membulatkan nilai epoch ms kembali ke DateTime UTC', () {
      final note = Note.fromMap({
        'id': 'n1',
        'title': 'Catatan',
        'body': 'Isi',
        'updated_at': sampleMillis,
        'is_dirty': 0,
        'deleted_at': null,
        'remote_revision': 3,
      });

      expect(note.updatedAt, sample);
      expect(note.updatedAt.isUtc, isTrue);
      expect(note.remoteRevision, 3);
      expect(note.isDeleted, isFalse);
    });

    test('kolom hilang tidak membuat crash dan memakai nilai default', () {
      final note = Note.fromMap({'id': 'n1'});

      expect(note.id, 'n1');
      expect(note.title, '');
      expect(note.body, '');
      expect(note.isDirty, isFalse);
      expect(note.deletedAt, isNull);
      expect(note.remoteRevision, 0);
      expect(note.updatedAt.millisecondsSinceEpoch, 0);
    });

    test('nilai null dan tipe tak terduga ditoleransi', () {
      final note = Note.fromMap({
        'id': 'n1',
        'title': null,
        'body': 42,
        'updated_at': null,
        'is_dirty': '1',
        'deleted_at': 'abc',
        'remote_revision': '7',
      });

      expect(note.title, '');
      expect(note.body, '');
      expect(note.updatedAt.millisecondsSinceEpoch, 0);
      expect(note.isDirty, isTrue, reason: 'string "1" harus dibaca sebagai dirty');
      expect(note.deletedAt, isNull, reason: 'nilai yang tidak valid jadi null');
      expect(note.remoteRevision, 7);
    });

    test('deleted_at == 0 dianggap belum dihapus', () {
      final note = Note.fromMap({
        'id': 'n1',
        'deleted_at': 0,
      });

      expect(note.isDeleted, isFalse);
    });
  });

  group('round-trip', () {
    test('toMap lalu fromMap mengembalikan objek yang sama', () {
      final original = Note(
        id: 'n1',
        title: 'Ronde-trip',
        body: 'isi\n\nberbaris',
        updatedAt: sample,
        isDirty: true,
        deletedAt: sample,
        remoteRevision: 5,
      );

      expect(Note.fromMap(original.toMap()), original);
    });
  });

  group('perubahan status', () {
    test('markChanged menyalakan isDirty dan memberi updatedAt baru', () {
      final before = Note(id: 'n1', title: 'x', updatedAt: sample);

      final after = before.markChanged(at: sample.add(const Duration(minutes: 5)));

      expect(after.isDirty, isTrue);
      expect(after.updatedAt.isAfter(sample), isTrue);
      expect(before.isDirty, isFalse, reason: 'model lama harus tetap immutable');
    });

    test('markSynced mematikan isDirty dan menyimpan revisi server', () {
      final before = Note(id: 'n1', title: 'x', updatedAt: sample, isDirty: true);

      final after = before.markSynced(revision: 4);

      expect(after.isDirty, isFalse);
      expect(after.remoteRevision, 4);
    });

    test('copyWith bisa mengosongkan deletedAt secara eksplisit', () {
      final tombstone = Note(
        id: 'n1',
        title: 'x',
        updatedAt: sample,
        deletedAt: sample,
      );

      expect(tombstone.copyWith().isDeleted, isTrue);
      expect(tombstone.copyWith(deletedAt: null).isDeleted, isFalse);
    });
  });

  group('tampilan', () {
    test('judul kosong punya teks pengganti', () {
      expect(
        Note(id: 'n1', title: '   ', updatedAt: sample).displayTitle,
        '(tanpa judul)',
      );
    });

    test('preview meratakan spasi dan baris baru', () {
      final note = Note(
        id: 'n1',
        title: 'x',
        body: '  baris satu\n\n  baris   dua \n',
        updatedAt: sample,
      );

      expect(note.preview, 'baris satu baris dua');
    });
  });

  group('generateNoteId', () {
    test('unik dan tidak kosong', () {
      final ids = List.generate(200, (_) => generateNoteId());

      expect(ids.toSet().length, ids.length);
      expect(ids.first, isNotEmpty);
    });
  });
}
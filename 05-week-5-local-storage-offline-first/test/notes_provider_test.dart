import 'package:ai_challenge/src/core/storage/preferences_provider.dart';
import 'package:ai_challenge/src/core/storage/preferences_service.dart';
import 'package:ai_challenge/src/features/notes/application/note_providers.dart';
import 'package:ai_challenge/src/features/notes/data/note_repository.dart';
import 'package:ai_challenge/src/features/notes/domain/note.dart';
import 'package:ai_challenge/src/features/notes/domain/sync_report.dart';
import 'package:ai_challenge/src/features/settings/application/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository palsu berbasis memory.
///
/// Tujuannya: membuktikan seluruh provider bekerja tanpa SQLite dan tanpa
/// jaringan. Kalau suatu saat ada test yang butuh `sqflite` sungguhan, ini
/// pengingat bahwa arsitekturnya memang memungkinkan — UI hanya tahu
/// [NoteRepository].
class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository({List<Note>? seed}) {
    for (final note in seed ?? const <Note>[]) {
      _notes[note.id] = note;
    }
  }

  final Map<String, Note> _notes = {};
  int _revision = 0;
  int _newId = 0;

  DateTime _clock = DateTime.utc(2026, 3, 14, 8);

  /// Jam internal repository, dipakai test untuk mengecek penamaan timestamp.
  DateTime get clock => _clock;

  /// Jika `true`, `syncNotes` melempar error.
  bool failSync = false;

  /// Laporan yang dikembalikan `refreshCache` bila tidak ada.
  SyncReport? nextReport;

  /// Laporan khas kondisi offline.
  SyncReport offlineReport() {
    return SyncReport.offline(
      startedAt: _clock,
      pendingAfter: _notes.values.where((note) => note.isDirty).length,
    );
  }

  @override
  Future<List<Note>> loadNotes() async {
    final visible = _notes.values.where((note) => !note.isDeleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return visible;
  }

  @override
  Future<Note?> findNote(String id) async => _notes[id];

  @override
  Future<Note> createNote({required String title, String body = ''}) async {
    final note = Note(
      id: 'note-${_newId++}',
      title: title,
      body: body,
      updatedAt: _clock,
      isDirty: true,
    );
    _notes[note.id] = note;
    return note;
  }

  @override
  Future<Note> updateNote(Note note) async {
    final stored = note.copyWith(updatedAt: _clock, isDirty: true);
    _notes[stored.id] = stored;
    return stored;
  }

  @override
  Future<void> deleteNote(String id) async {
    final existing = _notes[id];
    if (existing == null) return;
    _notes[id] = existing.copyWith(deletedAt: _clock, isDirty: true);
  }

  @override
  Future<int> pendingUploadCount() async {
    return _notes.values.where((note) => note.isDirty).length;
  }

  @override
  Future<CacheStatus> cacheStatus() async {
    return CacheStatus(
      noteCount: (await loadNotes()).length,
      pendingUploads: await pendingUploadCount(),
    );
  }

  @override
  Future<SyncReport> refreshCache() async => nextReport ?? offlineReport();

  @override
  Future<SyncReport> syncNotes() async {
    if (failSync) throw StateError('jaringan mati');

    var pushed = 0;
    for (final entry in _notes.entries.toList()) {
      if (!entry.value.isDirty) continue;
      _notes[entry.key] = entry.value.markSynced(revision: ++_revision);
      pushed += 1;
    }
    _clock = _clock.add(const Duration(minutes: 1));
    return nextReport = SyncReport(
      startedAt: _clock,
      reachedServer: true,
      pushed: pushed,
      pendingAfter: await pendingUploadCount(),
    );
  }

  /// Membiarkan test menyuntik baris yang tidak terlihat oleh UI, untuk
  /// membuktikan daftar selalu dibaca ulang dari repository.
  Note seed(Note note) {
    _notes[note.id] = note;
    return note;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNoteRepository fake;

  /// `SharedPreferences` palsu. Provider preferensi sengaja `throw` kalau tidak
  /// di-override, jadi test juga membuktikan batas itu bekerja.
  Future<PreferencesService> fakePreferences() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return PreferencesService.load();
  }

  Future<ProviderContainer> makeContainer({NoteRepository? repository}) async {
    fake = FakeNoteRepository();
    final container = ProviderContainer(
      overrides: [
        preferencesServiceProvider.overrideWithValue(await fakePreferences()),
        noteRepositoryProvider.overrideWithValue(repository ?? fake),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('notesProvider', () {
    test('mengurutkan catatan terbaru lebih dulu', () async {
      final container = await makeContainer(
        repository: FakeNoteRepository(seed: [
          Note(id: 'lama', title: 'Lama', updatedAt: DateTime.utc(2026, 1)),
          Note(id: 'baru', title: 'Baru', updatedAt: DateTime.utc(2026, 5)),
        ]),
      );

      final notes = await container.read(notesProvider.future);

      expect(notes.map((note) => note.id), ['baru', 'lama']);
    });

    test('addNote menyimpan lokal dan menyalakan badge dirty', () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);

      final created = await container
          .read(notesProvider.notifier)
          .addNote(title: 'Catatan dari provider');

      expect(created.title, 'Catatan dari provider');
      expect(created.isDirty, isTrue,
          reason: 'setiap tulisan lokal harus masuk antrean unggah');
      expect(container.read(notesProvider).value, hasLength(1));
      expect(await fake.pendingUploadCount(), 1);
    });

    test('addNote memakai updatedAt dari sumber waktu repository', () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);

      await container.read(notesProvider.notifier).addNote(title: 'x');

      expect((await fake.loadNotes()).single.updatedAt, fake.clock);
    });

    test('daftar mengikuti setiap mutasi: tambah, ubah, hapus', () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);
      final notifier = container.read(notesProvider.notifier);

      await notifier.addNote(title: 'Satu');
      await notifier.addNote(title: 'Dua');
      expect(container.read(notesProvider).value, hasLength(2));

      final target = container.read(notesProvider).value!.last;
      await notifier.updateNote(target.copyWith(title: 'Satu diedit'));
      expect(
        container.read(notesProvider).value!.any((n) => n.title == 'Satu diedit'),
        isTrue,
      );

      await notifier.deleteNote(target.id);
      expect(container.read(notesProvider).value, hasLength(1));
    });

    test('reload membaca ulang dari repository, bukan dari state lama', () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);
      fake.seed(Note(
        id: 'luar',
        title: 'Disisipkan dari luar',
        updatedAt: DateTime.utc(2026, 6),
      ));

      await container.read(notesProvider.notifier).reload();

      expect(container.read(notesProvider).value, hasLength(1));
    });

    test('catatan yang dihapus hilang dari daftar tapi tetap jadi antrean',
        () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);
      final created =
          await container.read(notesProvider.notifier).addNote(title: 'Hapus saya');

      await container.read(notesProvider.notifier).deleteNote(created.id);

      expect(container.read(notesProvider).value, isEmpty);
      expect(await fake.pendingUploadCount(), 1,
          reason: 'soft delete harus tetap dikirim ke server');
    });

    test('kegagalan load tersimpan di state error, UI punya jalur error sendiri',
        () async {
      final container = await makeContainer(
        repository: _ExplodingRepository(),
      );

      // `.future` meneruskan error, sementara state menyimpan AsyncValue.error —
      // itulah yang membuat `NotesPage` bisa menampilkan tombol "Coba lagi".
      await expectLater(
        container.read(notesProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(container.read(notesProvider).hasError, isTrue);
      expect(container.read(notesProvider).error, isA<StateError>());
    });
  });

  group('pendingUploadCountProvider', () {
    test('menghitung catatan dirty dan menjadi nol setelah sinkron', () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);
      await container.read(notesProvider.notifier).addNote(title: 'a');
      await container.read(notesProvider.notifier).addNote(title: 'b');

      container.invalidate(pendingUploadCountProvider);
      expect(await container.read(pendingUploadCountProvider.future), 2);

      await container.read(syncProvider.notifier).sync();
      expect(await container.read(pendingUploadCountProvider.future), 0);
    });
  });

  group('syncProvider', () {
    test('sync mengembalikan laporan dan membersihkan antrean', () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);
      await container.read(notesProvider.notifier).addNote(title: 'a');

      final report = await container.read(syncProvider.notifier).sync();

      expect(report, isNotNull);
      expect(report!.pushed, 1);
      expect(container.read(syncProvider).value, report);
      expect(await fake.pendingUploadCount(), 0);
    });

    test('kegagalan sinkron tidak melempar exception ke pemanggil', () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);
      fake.failSync = true;

      final report = await container.read(syncProvider.notifier).sync();

      expect(report, isNull);
      expect(container.read(syncProvider).hasError, isTrue);
    });

    test('sync menyegarkan daftar, jumlah antrean, dan status cache', () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);

      await container.read(syncProvider.notifier).sync();

      expect(container.read(notesProvider).value, isNotNull);
      expect(await container.read(pendingUploadCountProvider.future), 0);
      expect(await container.read(cacheStatusProvider.future), isNotNull);
    });
  });

  group('isOnlineProvider', () {
    test('sakelar mode pesawat membuat aplikasi terdeteksi offline', () async {
      final container = await makeContainer();
      await container.read(notesProvider.future);

      expect(container.read(isOnlineProvider), isTrue);

      await container.read(simulateOfflineProvider.notifier).setOffline(true);

      expect(container.read(isOnlineProvider), isFalse);
    });
  });

  group('themeModeProvider', () {
    test('toggleDark berbalik antara gelap dan terang', () async {
      final container = await makeContainer();
      final notifier = container.read(themeModeProvider.notifier);

      expect(container.read(themeModeProvider), ThemeMode.system);

      await notifier.toggleDark();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      await notifier.toggleDark();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('provider tanpa override', () {
    test('preferencesServiceProvider gagal cepat, bukan memakai nilai palsu',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod membungkus error provider dalam `ProviderException`, jadi yang
      // diuji di sini adalah sifat "gagal cepat", bukan tipe exception-nya.
      expect(
        () => container.read(preferencesServiceProvider),
        throwsA(anything),
      );
    });

    test('noteDatabaseProvider gagal cepat tanpa injeksi', () async {
      final container = ProviderContainer(
        overrides: [preferencesServiceProvider.overrideWithValue(await fakePreferences())],
      );
      addTearDown(container.dispose);

      expect(() => container.read(noteDatabaseProvider), throwsA(anything));
    });
  });
}

/// Repository yang selalu gagal, untuk menguji jalur error.
class _ExplodingRepository implements NoteRepository {
  @override
  Future<List<Note>> loadNotes() async => throw StateError('cache rusak');

  @override
  Future<Note?> findNote(String id) async => null;

  @override
  Future<Note> createNote({required String title, String body = ''}) =>
      throw UnimplementedError();

  @override
  Future<Note> updateNote(Note note) => throw UnimplementedError();

  @override
  Future<void> deleteNote(String id) => throw UnimplementedError();

  @override
  Future<int> pendingUploadCount() async => 0;

  @override
  Future<CacheStatus> cacheStatus() async =>
      const CacheStatus(noteCount: 0, pendingUploads: 0);

  @override
  Future<SyncReport> refreshCache() => throw UnimplementedError();

  @override
  Future<SyncReport> syncNotes() => throw UnimplementedError();
}
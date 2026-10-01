import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_notes/data/local/note.dart';
import 'package:offline_notes/data/remote/notes_api.dart';
import 'package:offline_notes/data/sync/sync_service.dart';
import 'package:offline_notes/providers/app_providers.dart';

import 'support/fakes.dart';

/// Test provider dengan repository palsu: tidak ada SQLite, tidak ada jaringan.
void main() {
  final base = DateTime(2026, 4, 1, 10);

  Note synced(int id, String title, Duration ago) => Note(
    id: id,
    title: title,
    body: 'isi $title',
    createdAt: base.subtract(ago + const Duration(days: 1)),
    updatedAt: base.subtract(ago),
    status: SyncStatus.synced,
  );

  ProviderContainer buildContainer({
    required FakeNoteRepository repository,
    NotesApi? api,
    bool online = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        notesApiProvider.overrideWithValue(api ?? ImmediateNotesApi()),
        isOnlineProvider.overrideWith(() => TestIsOnline(online)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('notesControllerProvider', () {
    test(
      'cache-first: daftar tampil dari lokal tanpa memanggil server',
      () async {
        final repository = FakeNoteRepository([
          synced(1, 'Lama', const Duration(days: 2)),
          synced(2, 'Baru', const Duration(hours: 1)),
        ]);
        final api = ImmediateNotesApi();
        final container = buildContainer(repository: repository, api: api);

        final notes = await container.read(notesControllerProvider.future);

        expect(notes.map((note) => note.title), ['Baru', 'Lama']);
        expect(api.serverNotes, isEmpty, reason: 'server tidak boleh disentuh');
      },
    );

    test('menambah catatan baru langsung menyalakan badge dirty', () async {
      final repository = FakeNoteRepository();
      final container = buildContainer(repository: repository);
      await container.read(notesControllerProvider.future);

      await container
          .read(notesControllerProvider.notifier)
          .addNote(title: 'Catatan offline', body: 'ditulis tanpa jaringan');

      final notes = await container.read(notesControllerProvider.future);
      expect(notes.single.isDirty, isTrue);
      expect(await repository.countPending(), 1);
    });

    test(
      'menyunting catatan mengembalikan daftar terurut terbaru dulu',
      () async {
        final repository = FakeNoteRepository([
          synced(1, 'Awal', const Duration(days: 5)),
          synced(2, 'Kedua', const Duration(days: 3)),
        ]);
        final container = buildContainer(repository: repository);
        await container.read(notesControllerProvider.future);

        final controller = container.read(notesControllerProvider.notifier);
        await controller.editNote(
          (await repository.fetchNoteById(1))!
              .copyWith(title: 'Awal diperbarui'),
        );

        final notes = await container.read(notesControllerProvider.future);
        expect(notes.first.title, 'Awal diperbarui');
        expect(notes.first.isDirty, isTrue);
      },
    );

    test('badge dirty kosong setelah syncPending berhasil', () async {
      final repository = FakeNoteRepository();
      final api = ImmediateNotesApi();
      final container = buildContainer(repository: repository, api: api);
      await container.read(notesControllerProvider.future);

      await container
          .read(notesControllerProvider.notifier)
          .addNote(title: 'Perlu dikirim');
      expect(await repository.countPending(), 1);

      final report = await container
          .read(notesControllerProvider.notifier)
          .syncPending();

      expect(report.status, SyncRunStatus.completed);
      expect(report.pushed, 1);
      expect(await repository.countPending(), 0);
      expect(api.serverNotes, hasLength(1));
    });

    test(
      'offline: syncPending tidak menyentuh server dan data tetap ada',
      () async {
        final repository = FakeNoteRepository();
        final api = ImmediateNotesApi();
        final container = buildContainer(
          repository: repository,
          api: api,
          online: false,
        );
        await container.read(notesControllerProvider.future);

        await container
            .read(notesControllerProvider.notifier)
            .addNote(title: 'Dibuat di pesawat');

        final report = await container
            .read(notesControllerProvider.notifier)
            .syncPending();

        expect(report.status, SyncRunStatus.offline);
        expect(api.serverNotes, isEmpty);
        expect(await repository.countPending(), 1);

        // Daftar tetap terbaca: inilah bukti mode pesawat.
        final notes = await container.read(notesControllerProvider.future);
        expect(notes.single.title, 'Dibuat di pesawat');
      },
    );

    test(
      'server gagal: cache lokal tidak hilang dan status jadi failed',
      () async {
        final repository = FakeNoteRepository([
          synced(1, 'Tersimpan', Duration.zero),
        ]);
        final api = AlwaysFailingNotesApi();
        final container = buildContainer(repository: repository, api: api);

        final report = await container
            .read(notesControllerProvider.notifier)
            .refreshFromServer();

        expect(report.status, SyncRunStatus.failed);
        expect(api.fetchAttempts, greaterThan(0));

        final notes = await container.read(notesControllerProvider.future);
        expect(notes.single.title, 'Tersimpan');
      },
    );
  });

  group('syncCountsProvider', () {
    test('jumlah pending dan conflicted dihitung terpisah', () async {
      final repository = FakeNoteRepository([
        synced(1, 'Bersih', Duration.zero),
        synced(
          2,
          'Menunggu',
          Duration.zero,
        ).copyWith(status: SyncStatus.pendingUpload),
        synced(
          3,
          'Konflik',
          Duration.zero,
        ).copyWith(status: SyncStatus.conflicted),
      ]);
      final container = buildContainer(repository: repository);
      await container.read(notesControllerProvider.future);

      final counts = await container.read(syncCountsProvider.future);

      expect(counts.pending, 1);
      expect(counts.conflicted, 1);
      expect(counts.total, 2);
      expect(counts.isClean, isFalse);
    });
  });
}

/// Override nilai tetap untuk [isOnlineProvider] supaya status jaringan bisa
/// dikunci selama test.
class TestIsOnline extends IsOnlineController {
  TestIsOnline(this.online);

  final bool online;

  @override
  bool build() => online;
}

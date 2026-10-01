import 'package:flutter_test/flutter_test.dart';
import 'package:offline_notes/data/local/note.dart';
import 'package:offline_notes/data/remote/notes_api.dart';
import 'package:offline_notes/data/sync/conflict_resolver.dart';
import 'package:offline_notes/data/sync/sync_service.dart';

import 'support/fakes.dart';

/// Test aturan konflik dan alur sinkronisasi, tanpa SQLite dan tanpa jaringan.
void main() {
  final base = DateTime(2026, 6, 1, 12);

  Note local({
    required int id,
    required SyncStatus status,
    required Duration ago,
    String title = 'Versi lokal',
  }) => Note(
    id: id,
    title: title,
    body: 'isi lokal',
    createdAt: base.subtract(const Duration(days: 2)),
    updatedAt: base.subtract(ago),
    status: status,
  );

  Note remote({
    required int id,
    required Duration ago,
    String title = 'Versi server',
  }) => Note(
    id: id,
    title: title,
    body: 'isi server',
    createdAt: base.subtract(const Duration(days: 2)),
    updatedAt: base.subtract(ago),
    status: SyncStatus.synced,
  );

  group('ConflictResolver', () {
    const resolver = ConflictResolver();

    test('hanya server yang berubah -> tarik versi server', () {
      final result = resolver.resolve(
        local(id: 1, status: SyncStatus.synced, ago: const Duration(days: 1)),
        remote(id: 1, ago: const Duration(hours: 1)),
      );

      expect(result, ConflictResolution.pullRemote);
      expect(resolver.statusAfter(result), SyncStatus.synced);
    });

    test('lokal berubah, server tidak lebih baru -> fast-forward', () {
      final result = resolver.resolve(
        local(
          id: 1,
          status: SyncStatus.pendingUpload,
          ago: const Duration(minutes: 5),
        ),
        remote(id: 1, ago: const Duration(hours: 1)),
      );

      expect(result, ConflictResolution.pushLocal);
      expect(resolver.statusAfter(result), SyncStatus.pendingUpload);
    });

    test(
      'kedua sisi berubah dan server lebih baru -> eskalasi ke pengguna',
      () {
        final result = resolver.resolve(
          local(
            id: 1,
            status: SyncStatus.pendingUpload,
            ago: const Duration(minutes: 5),
          ),
          remote(id: 1, ago: const Duration(minutes: 1)),
        );

        expect(result, ConflictResolution.needsUserDecision);
        expect(resolver.statusAfter(result), SyncStatus.conflicted);
      },
    );

    test('catatan hanya ada di server -> diterima tanpa konflik', () {
      final result = resolver.resolve(null, remote(id: 9, ago: Duration.zero));

      expect(result, ConflictResolution.pullRemote);
    });

    test('catatan hanya ada di lokal -> tetap diunggah', () {
      final result = resolver.resolve(
        local(id: 9, status: SyncStatus.pendingUpload, ago: Duration.zero),
        null,
      );

      expect(result, ConflictResolution.pushLocal);
    });
  });

  group('SyncService.syncNotes', () {
    SyncService build(
      FakeNoteRepository repository,
      NotesApi api, {
      bool online = true,
    }) => SyncService(repository, api, () => online);

    test('mengunggah antrean lalu mengosongkan dirty flag', () async {
      final repository = FakeNoteRepository();
      final api = ImmediateNotesApi();
      final service = build(repository, api);

      await repository.createNote(title: 'Satu');
      await repository.createNote(title: 'Dua');

      final report = await service.syncNotes();

      expect(report.status, SyncRunStatus.completed);
      expect(report.pushed, 2);
      expect(await repository.countPending(), 0);
      expect(api.serverNotes, hasLength(2));
    });

    test('offline: tidak ada permintaan ke server sama sekali', () async {
      final repository = FakeNoteRepository();
      final api = ImmediateNotesApi();
      final service = build(repository, api, online: false);
      await repository.createNote(title: 'Menunggu internet');

      final report = await service.syncNotes();

      expect(report.status, SyncRunStatus.offline);
      expect(api.serverNotes, isEmpty);
      expect(await repository.countPending(), 1);
    });

    test(
      'server menolak versi lama: konflik ditandai, isi lokal tidak hilang',
      () async {
        final repository = FakeNoteRepository();
        final api = ImmediateNotesApi([remote(id: 1, ago: Duration.zero)]);
        final service = build(repository, api);

        repository.seed(
          local(
            id: 1,
            status: SyncStatus.pendingUpload,
            ago: const Duration(hours: 2),
          ),
        );

        final report = await service.syncNotes();

        expect(report.status, SyncRunStatus.needsDecision);
        expect(report.conflicts, 1);
        expect(await repository.countConflicted(), 1);
        expect((await repository.fetchNoteById(1))!.title, 'Versi lokal');
      },
    );

    test(
      'catatan konflik tidak ikut terunggah pada putaran berikutnya',
      () async {
        final repository = FakeNoteRepository();
        final api = ImmediateNotesApi();
        final service = build(repository, api);

        repository.seed(
          local(
            id: 1,
            status: SyncStatus.conflicted,
            ago: const Duration(minutes: 10),
          ),
        );

        final report = await service.syncNotes();

        expect(report.pushed, 0);
        expect(api.serverNotes, isEmpty);
        expect(await repository.countConflicted(), 1);
      },
    );

    test('keputusan "pakai versi ini" mengunggah ulang versi lokal', () async {
      final repository = FakeNoteRepository();
      final api = ImmediateNotesApi([remote(id: 1, ago: Duration.zero)]);
      final service = build(repository, api);

      repository.seed(
        local(
          id: 1,
          status: SyncStatus.conflicted,
          ago: const Duration(hours: 3),
          title: 'Milik saya',
        ),
      );

      final report = await service.keepLocalVersion(1);

      expect(report.status, SyncRunStatus.completed);
      expect(report.pushed, 1);
      expect(await repository.countConflicted(), 0);
      expect(api.serverNotes.single.title, 'Milik saya');
    });

    test('keputusan "pakai versi server" menimpa isi lokal', () async {
      final repository = FakeNoteRepository();
      final api = ImmediateNotesApi([remote(id: 1, ago: Duration.zero)]);
      final service = build(repository, api);

      repository.seed(
        local(
          id: 1,
          status: SyncStatus.conflicted,
          ago: const Duration(hours: 3),
          title: 'Versi lokal',
        ),
      );

      final report = await service.keepRemoteVersion(1);

      expect(report.status, SyncRunStatus.completed);
      expect((await repository.fetchNoteById(1))!.title, 'Versi server');
      expect(await repository.countConflicted(), 0);
    });
  });

  group('SyncService.pullAndMerge', () {
    test('menarik catatan yang belum ada di perangkat ini', () async {
      final repository = FakeNoteRepository();
      final api = ImmediateNotesApi([
        remote(id: 5, ago: Duration.zero),
        remote(id: 6, ago: const Duration(hours: 1)),
      ]);
      final service = SyncService(repository, api, () => true);

      final report = await service.pullAndMerge();

      expect(report.status, SyncRunStatus.completed);
      expect(report.pulled, 2);
      expect(await repository.fetchNotes(), hasLength(2));
    });

    test('tidak menimpa suntingan lokal yang lebih baru', () async {
      final repository = FakeNoteRepository();
      final api = ImmediateNotesApi([
        remote(id: 1, ago: const Duration(hours: 5), title: 'Bekas di server'),
      ]);
      final service = SyncService(repository, api, () => true);

      repository.seed(
        local(
          id: 1,
          status: SyncStatus.pendingUpload,
          ago: const Duration(minutes: 5),
          title: 'Suntingan terbaru',
        ),
      );

      final report = await service.pullAndMerge();

      expect(report.pulled, 0);
      expect(report.conflicts, 0);
      expect((await repository.fetchNoteById(1))!.title, 'Suntingan terbaru');
    });

    test('menarik versi server bila lokal belum pernah diubah', () async {
      final repository = FakeNoteRepository();
      final api = ImmediateNotesApi([
        remote(
          id: 1,
          ago: const Duration(hours: 1),
          title: 'Terbaru dari server',
        ),
      ]);
      final service = SyncService(repository, api, () => true);

      repository.seed(
        local(
          id: 1,
          status: SyncStatus.synced,
          ago: const Duration(days: 2),
          title: 'Lama di perangkat',
        ),
      );

      final report = await service.pullAndMerge();

      expect(report.pulled, 1);
      expect((await repository.fetchNoteById(1))!.title, 'Terbaru dari server');
    });
  });
}

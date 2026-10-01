import 'package:ai_challenge/src/features/notes/domain/conflict.dart';
import 'package:ai_challenge/src/features/notes/domain/note.dart';
import 'package:ai_challenge/src/features/notes/domain/remote_note.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test untuk [resolveConflict].
///
/// Fungsinya mengunci aturan yang ditulis di `docs/docs_03_offline_first.md`.
/// Kalau aturan diubah, test ini harus ikut gagal — bukan ikut berubah diam-diam.
void main() {
  final now = DateTime.utc(2026, 3, 14, 12);
  final localUpdated = DateTime.utc(2026, 3, 14, 9);
  final remoteUpdated = DateTime.utc(2026, 3, 14, 11);

  String nextId() => 'salinan-1';

  Note localNote({
    int remoteRevision = 1,
    bool isDirty = true,
    DateTime? deletedAt,
    String title = 'Catatan',
  }) {
    return Note(
      id: 'n1',
      title: title,
      body: 'isi lokal',
      updatedAt: localUpdated,
      isDirty: isDirty,
      deletedAt: deletedAt,
      remoteRevision: remoteRevision,
    );
  }

  RemoteNote remoteNote({
    int revision = 2,
    bool deleted = false,
    String title = 'Catatan',
  }) {
    return RemoteNote(
      id: 'n1',
      title: title,
      body: 'isi server',
      updatedAt: remoteUpdated,
      revision: revision,
      deleted: deleted,
    );
  }

  ConflictResolution resolve(Note local, RemoteNote? remote, ConflictStrategy s) {
    return resolveConflict(
      local: local,
      remote: remote,
      strategy: s,
      idFactory: nextId,
      clock: () => now,
    );
  }

  group('tidak ada konflik sama sekali', () {
    test('server belum punya catatan → insert, tanpa laporan konflik', () {
      final result = resolve(localNote(), null, ConflictStrategy.remoteWins);

      expect(result.decision, ConflictDecision.push);
      expect(result.toPush?.id, 'n1');
      expect(result.hasConflict, isFalse);
    });

    test('server tidak berubah sejak sinkron terakhir → fast-forward', () {
      final result = resolve(
        localNote(remoteRevision: 3),
        remoteNote(revision: 3),
        ConflictStrategy.remoteWins,
      );

      expect(result.decision, ConflictDecision.push);
      expect(result.toPush?.title, 'Catatan');
      expect(result.hasConflict, isFalse,
          reason: 'kasus mayoritas tidak boleh dilaporkan sebagai konflik');
    });

    test('revisi server lebih kecil juga dianggap aman', () {
      final result = resolve(
        localNote(remoteRevision: 5),
        remoteNote(revision: 2),
        ConflictStrategy.localWins,
      );

      expect(result.hasConflict, isFalse);
    });
  });

  group('konflik suntingan bersamaan', () {
    test('server menang → versi server ditulis, tidak ada yang diunggah', () {
      final result = resolve(localNote(), remoteNote(), ConflictStrategy.remoteWins);

      expect(result.decision, ConflictDecision.acceptRemote);
      expect(result.toPush, isNull);
      expect(result.localToStore?.title, 'Catatan');
      expect(result.localToStore?.body, 'isi server');
      expect(result.localToStore?.isDirty, isFalse);
      expect(result.localToStore?.remoteRevision, 2);
      expect(result.conflict?.reason, ConflictReason.concurrentEdit);
    });

    test('lokal menang → versi lokal dipaksa kirim', () {
      final result = resolve(localNote(), remoteNote(), ConflictStrategy.localWins);

      expect(result.decision, ConflictDecision.forcePush);
      expect(result.toPush?.body, 'isi lokal');
      expect(result.localToStore?.body, 'isi lokal');
      expect(result.conflict?.outcome, contains('paksa'));
    });

    test('simpan keduanya → server dipakai, lokal jadi catatan baru', () {
      final result = resolve(localNote(), remoteNote(), ConflictStrategy.keepBoth);

      expect(result.decision, ConflictDecision.duplicateLocal);
      expect(result.localToStore?.id, 'n1', reason: 'slot id asli diisi versi server');
      expect(result.localToStore?.body, 'isi server');

      final copy = result.toPush!;
      expect(copy.id, 'salinan-1', reason: 'id baru, bukan menimpa id asli');
      expect(copy.title, 'Catatan (konflik)');
      expect(copy.body, 'isi lokal');
      expect(copy.isDirty, isTrue, reason: 'harus ikut diunggah');
      expect(copy.updatedAt, now);
    });

    test('setiap konflik menyimpan alasan dan tindakan yang dijalankan', () {
      for (final strategy in ConflictStrategy.values) {
        final record = resolve(localNote(), remoteNote(), strategy).conflict!;

        expect(record.noteId, 'n1');
        expect(record.noteTitle, 'Catatan');
        expect(record.strategy, strategy);
        expect(record.reasonLabel, 'diubah di dua perangkat');
        expect(record.outcomeLabel, isNotEmpty);
      }
    });
  });

  group('penghapusan menang atas perubahan, dari kedua sisi', () {
    test('tombstone lokal + server berubah → hapusannya yang dikirim', () {
      final result = resolve(
        localNote(deletedAt: localUpdated),
        remoteNote(),
        ConflictStrategy.keepBoth,
      );

      expect(result.decision, ConflictDecision.push);
      expect(result.toPush?.isDeleted, isTrue);
      expect(result.conflict?.reason, ConflictReason.localDelete);
      expect(result.conflict?.outcome, 'penghapusan dikirim ke server');
    });

    test('server sudah hapus + ada perubahan lokal → terima hapusannya', () {
      final result = resolve(
        localNote(),
        remoteNote(deleted: true),
        ConflictStrategy.localWins,
      );

      expect(result.decision, ConflictDecision.acceptRemote);
      expect(result.toPush, isNull,
          reason: 'perubahan lokal tidak boleh menghidupkan catatan yang dihapus');
      expect(result.localToStore?.isDeleted, isTrue);
      expect(result.localToStore?.isDirty, isFalse);
      expect(result.localToStore?.deletedAt, remoteUpdated);
      expect(result.conflict?.reason, ConflictReason.remoteDeleted);
    });

    test('kebijakan hapus mengabaikan strategi yang dipilih pengguna', () {
      for (final strategy in ConflictStrategy.values) {
        final result = resolve(
          localNote(),
          remoteNote(deleted: true),
          strategy,
        );

        expect(result.decision, ConflictDecision.acceptRemote,
            reason: 'strategi $strategy tidak boleh menghidupkan catatan terhapus');
      }
    });
  });

  group('determinisme', () {
    test('hasil fungsi murni: input sama → output sama', () {
      final a = resolve(localNote(), remoteNote(), ConflictStrategy.keepBoth);
      final b = resolve(localNote(), remoteNote(), ConflictStrategy.keepBoth);

      expect(a.localToStore, b.localToStore);
      expect(a.toPush, b.toPush);
      expect(a.decision, b.decision);
    });
  });
}
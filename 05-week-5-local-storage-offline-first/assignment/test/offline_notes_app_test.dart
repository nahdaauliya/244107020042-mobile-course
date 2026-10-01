import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_notes/data/local/note.dart';
import 'package:offline_notes/main.dart';
import 'package:offline_notes/providers/app_providers.dart';

import 'support/fakes.dart';

/// Widget test untuk jalur offline-first yang terlihat di layar:
/// daftar tetap tampil dari cache, badge dirty muncul, dan tombol Sync
/// nonaktif saat mode pesawat.
void main() {
  final base = DateTime(2026, 6, 1, 12);

  Note note(int id, String title, Duration ago, SyncStatus status) => Note(
    id: id,
    title: title,
    body: 'isi $title',
    createdAt: base.subtract(ago + const Duration(days: 1)),
    updatedAt: base.subtract(ago),
    status: status,
  );

  Future<void> pumpApp(
    WidgetTester tester, {
    required List<Note> initial,
    bool online = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(FakeNoteRepository(initial)),
          notesApiProvider.overrideWithValue(ImmediateNotesApi()),
          isOnlineProvider.overrideWith(() => TestIsOnline(online)),
        ],
        child: const OfflineNotesApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('daftar catatan tampil dari cache lokal saat mode pesawat', (
    tester,
  ) async {
    await pumpApp(
      tester,
      online: false,
      initial: [
        note(1, 'Catatan lama', const Duration(days: 2), SyncStatus.synced),
        note(
          2,
          'Catatan baru',
          const Duration(minutes: 5),
          SyncStatus.pendingUpload,
        ),
      ],
    );

    expect(find.text('Catatan lama'), findsOneWidget);
    expect(find.text('Catatan baru'), findsOneWidget);
    expect(find.text('Mode pesawat aktif'), findsOneWidget);
    expect(find.text('Belum sinkron'), findsOneWidget);
    expect(find.text('Tersinkron'), findsOneWidget);
  });

  testWidgets('urutan daftar mengikuti updated_at terbaru', (tester) async {
    await pumpApp(
      tester,
      online: false,
      initial: [
        note(1, 'Paling lama', const Duration(days: 9), SyncStatus.synced),
        note(2, 'Paling baru', const Duration(minutes: 1), SyncStatus.synced),
        note(3, 'Di tengah', const Duration(days: 3), SyncStatus.synced),
      ],
    );

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();

    expect(titles, ['Paling baru', 'Di tengah', 'Paling lama']);
  });

  testWidgets('tombol Sinkron nonaktif saat offline dan aktif setelah online', (
    tester,
  ) async {
    await pumpApp(
      tester,
      online: false,
      initial: [note(1, 'Satu', Duration.zero, SyncStatus.pendingUpload)],
    );

    FilledButton syncButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sinkron'),
    );

    expect(syncButton().onPressed, isNull);

    await tester.tap(find.byTooltip('Aktifkan / matikan mode pesawat'));
    await tester.pumpAndSettle();

    expect(find.text('Mode pesawat aktif'), findsNothing);
    expect(syncButton().onPressed, isNotNull);
  });
}

class TestIsOnline extends IsOnlineController {
  TestIsOnline(this.online);

  final bool online;

  @override
  bool build() => online;
}

// Generator tangkapan layar untuk portofolio.
//
// Alat ini BUKAN bagian dari aplikasi dan tidak ikut dihitung sebagai test:
// `flutter test` hanya memindai folder `test/`, sedangkan berkas ini berada di
// `tool/`. Cara pakai:
//
//     flutter test tool/generate_screenshots.dart
//
// Yang direkam adalah widget tree aplikasi yang sungguhan (bukan gambar
// rekaan): `ProviderScope` dengan repository palsu berisi data contoh, lalu
// tiap kondisi offline-first dipotret dari state Riverpod yang nyata. Karena
// itu isi tangkapan layar selalu konsisten dengan kode.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_notes/data/local/note.dart';
import 'package:offline_notes/data/remote/notes_api.dart';
import 'package:offline_notes/main.dart';
import 'package:offline_notes/providers/app_providers.dart';

import '../test/support/fakes.dart';

/// Ukuran perangkat yang umum dipakai saat demo.
const Size _phone = Size(412, 892);
const double _pixelRatio = 2;

void main() {
  setUpAll(_loadRealFonts);

  final now = DateTime.now();

  Note sample(
    int id,
    String title,
    String body,
    Duration ago,
    SyncStatus status, {
    String conflict = '',
  }) => Note(
    id: id,
    title: title,
    body: body,
    createdAt: now.subtract(ago + const Duration(days: 2)),
    updatedAt: now.subtract(ago),
    status: status,
    conflictNote: conflict,
  );

  List<Note> contoh({required bool satuBelumSinkron}) => [
    sample(
      1,
      'Rencana Sprint 5',
      'Tuntaskan layer sinkronisasi, tulis aturan konflik, lalu buktikan '
          'dengan unit test.',
      const Duration(minutes: 4),
      satuBelumSinkron ? SyncStatus.pendingUpload : SyncStatus.synced,
    ),
    sample(
      2,
      'Ide mode gelap',
      'Simpan ThemeMode, bukan bool, supaya pilihan "ikuti sistem" tetap '
          'mungkin.',
      const Duration(hours: 3),
      SyncStatus.synced,
    ),
    sample(
      3,
      'Cache-first itu wajib',
      'Baris ini hanya ada di SQLite, jadi tetap tampil walau tidak ada '
          'jaringan.',
      const Duration(days: 2),
      SyncStatus.synced,
    ),
  ];

  testWidgets(
    '01 mode pesawat: daftar dari cache, badge dirty sebelum sinkron',
    (tester) async {
      await _pump(
        tester,
        repository: FakeNoteRepository(contoh(satuBelumSinkron: true)),
        online: false,
      );
      await _settle(tester);

      expect(find.text('Mode pesawat aktif'), findsOneWidget);
      expect(find.text('Belum sinkron'), findsOneWidget);
      await _shoot(tester, '01-mode-pesawat-daftar-dari-cache');
    },
  );

  testWidgets('02 mode pesawat: catatan baru tersimpan lokal lewat editor', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      repository: FakeNoteRepository(contoh(satuBelumSinkron: true)),
      online: false,
    );
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Judul').first,
      'Catatan ditulis di pesawat',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Isi catatan').first,
      'Dibuat tanpa jaringan. Masuk antrean sync dan menunggu koneksi.',
    );
    await tester.tap(find.text('Simpan'));
    await _settle(tester);

    expect(find.text('Catatan ditulis di pesawat'), findsOneWidget);
    expect(find.text('Belum sinkron'), findsNWidgets(2));
    container.read(notesControllerProvider);
    await _shoot(tester, '02-mode-pesawat-catatan-baru');
  });

  testWidgets('03 online: setelah sinkron semua badge jadi bersih', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      repository: FakeNoteRepository(contoh(satuBelumSinkron: true)),
      online: false,
    );
    await _settle(tester);
    expect(find.text('Belum sinkron'), findsOneWidget);

    // Koneksi dinyalakan: backgroundSyncProvider otomatis menarik dan mendorong.
    container.read(isOnlineProvider.notifier).goOnline();
    await _settle(tester);

    expect(find.text('Mode pesawat aktif'), findsNothing);
    expect(find.text('Belum sinkron'), findsNothing);
    expect(find.text('Tersinkron'), findsNWidgets(3));
    await _shoot(tester, '03-online-setelah-sinkron');
  });

  testWidgets('04 daftar utama bertema gelap', (tester) async {
    await _pump(
      tester,
      repository: FakeNoteRepository(contoh(satuBelumSinkron: true)),
      online: false,
      theme: ThemeMode.dark,
    );
    await _settle(tester);
    await _shoot(tester, '04-daftar-tema-gelap');
  });

  testWidgets('05 editor catatan bertema gelap', (tester) async {
    await _pump(
      tester,
      repository: FakeNoteRepository(contoh(satuBelumSinkron: true)),
      online: false,
      theme: ThemeMode.dark,
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await _settle(tester);
    await _shoot(tester, '05-editor-tema-gelap');
  });

  testWidgets('06 sheet resolusi konflik', (tester) async {
    await _pump(
      tester,
      repository: FakeNoteRepository([
        sample(
          1,
          'Ide mode gelap',
          'Simpan ThemeMode, bukan bool, supaya pilihan "ikuti sistem" tetap '
              'mungkin.',
          const Duration(minutes: 2),
          SyncStatus.conflicted,
          conflict:
              'Server lebih baru (12:04:11) daripada suntingan perangkat '
              'ini (11:58:03). Pilih versi yang dipakai.',
        ),
        sample(
          2,
          'Catatan lama',
          'Sudah tersinkron.',
          const Duration(days: 1),
          SyncStatus.synced,
        ),
      ]),
      online: true,
    );
    // Sheet dibuka otomatis oleh listener konflik di `main.dart`.
    await _settle(tester);

    expect(find.text('Konflik sinkron (1)'), findsOneWidget);
    await _shoot(tester, '06-konflik-perlu-diputuskan');
  });

  testWidgets('07 pengaturan: tema dan waktu terakhir dibuka', (tester) async {
    await _pump(
      tester,
      repository: FakeNoteRepository(contoh(satuBelumSinkron: true)),
      online: false,
      lastOpened: now.subtract(const Duration(hours: 5, minutes: 12)),
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await _settle(tester);
    await _shoot(tester, '07-pengaturan-preferensi');
  });

  testWidgets('08 daftar kosong', (tester) async {
    await _pump(tester, repository: FakeNoteRepository(), online: false);
    await _settle(tester);
    expect(find.text('Belum ada catatan'), findsOneWidget);
    await _shoot(tester, '08-daftar-kosong');
  });
}

/// Bangun aplikasi sungguhan dengan repository palsu berisi data contoh.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeNoteRepository repository,
  required bool online,
  NotesApi? api,
  ThemeMode theme = ThemeMode.light,
  DateTime? lastOpened,
}) async {
  tester.view
    ..physicalSize = _phone * _pixelRatio
    ..devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      noteRepositoryProvider.overrideWithValue(repository),
      notesApiProvider.overrideWithValue(api ?? ImmediateNotesApi()),
      isOnlineProvider.overrideWith(() => FixedOnline(online)),
      themeModeProvider.overrideWith(() => FixedTheme(theme)),
      lastOpenedProvider.overrideWith((ref) async => lastOpened),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RepaintBoundary(
        key: ValueKey('screenshot-root'),
        child: OfflineNotesApp(),
      ),
    ),
  );
  return container;
}

/// Beri kesempatan animasi, snackbar, dan siklus async provider selesai.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('screenshot-root')),
  );

  // `toImage` menunggu raster thread, jadi harus di dalam `runAsync`;
  // di luar itu future-nya tidak pernah selesai.
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;

    final file = File('screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List());
    // ignore: avoid_print
    print('screenshots/$name.png ditulis (${bytes.lengthInBytes} byte)');
  });
}

/// Mendaftarkan font sistem supaya teks pada tangkapan layar bukan kotak abu.
/// Nama keluarga didaftarkan sebagai 'Ahem' karena lingkungan test Flutter
/// memakai font placeholder dengan nama itu sebagai bawaan.
Future<void> _loadRealFonts() async {
  const files = ['segoeui.ttf', 'segoeuib.ttf', 'seguisb.ttf'];
  for (final name in files) {
    final file = File('C:/Windows/Fonts/$name');
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    for (final family in ['Roboto', 'Ahem']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  }
}

/// Kunci status jaringan selama generator berjalan.
class FixedOnline extends IsOnlineController {
  FixedOnline(this.value);

  final bool value;

  @override
  bool build() => value;
}

/// Kunci tema selama generator berjalan.
class FixedTheme extends ThemeModeController {
  FixedTheme(this.value);

  final ThemeMode value;

  @override
  ThemeMode build() => value;
}

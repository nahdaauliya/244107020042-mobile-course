import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/storage/preferences_provider.dart';
import 'src/core/storage/preferences_service.dart';
import 'src/features/notes/application/note_providers.dart';
import 'src/features/notes/data/note_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Preferensi di-load satu kali di sini, lalu di-override ke dalam
  //    ProviderScope.ollipopnya provider bisa jadi Notifier sinkron: tema dan
  //    "terakhir dibuka" sudah tersedia saat frame pertama, dan tidak ada race
  //    antara build pertama dan nilai preferensi.
  final preferences = await PreferencesService.load();

  // 2. SQLite dibuka sebelum `runApp` supaya halaman daftar tidak perlu
  //    menunggu pembuatan database pada frame pertama.
  final database = await NoteDatabase.open();

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferences),
        noteDatabaseProvider.overrideWithValue(database),
      ],
      child: const OfflineNotesApp(),
    ),
  );

  // 3. Catat waktu pembukaan. Nilai yang dibaca provider adalah pembukaan
  //    *sebelum* sesi ini, jadi penulisan dilakukan setelah `runApp`.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(preferences.writeLastOpenedAt(DateTime.now()));
  });
}

/// `unawaited` tanpa dependensi `dart:async` tambahan di file bootstrap.
void unawaited(Future<void> future) {
  future.catchError((Object error, StackTrace stackTrace) {
    debugPrint('Gagal menyimpan waktu terakhir dibuka: $error');
  });
}
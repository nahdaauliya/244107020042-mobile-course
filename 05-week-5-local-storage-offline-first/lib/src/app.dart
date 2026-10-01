import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/notes/application/note_providers.dart';
import 'features/notes/presentation/notes_page.dart';

/// Root widget.
///
/// Tema gelap/terang datang dari `themeModeProvider`, yang nilainya berasal dari
/// `SharedPreferences`. Karena preferensinya sudah di-load sebelum `runApp`,
/// aplikasi mulai langsung dalam tema yang benar — tanpa berkedip terang
/// selama beberapa frame pertama.
class OfflineNotesApp extends ConsumerWidget {
  const OfflineNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Catatan Offline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const NotesPage(),
    );
  }
}
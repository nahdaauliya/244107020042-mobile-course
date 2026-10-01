import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/local/note.dart';
import 'data/repositories/prefs_repository.dart';
import 'providers/app_providers.dart';
import 'pages/notes_page.dart';
import 'pages/note_editor_page.dart';
import 'pages/settings_page.dart';
import 'widgets/conflict_sheet.dart';

/// Kunci navigator teratas.
///
/// Diperlukan karena listener konflik di bawah berada di `builder` milik
/// `MaterialApp.router`, yaitu **di atas** `Navigator`. Tanpa kunci ini,
/// `showModalBottomSheet` akan gagal dengan "context that does not include a
/// Navigator".
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Konfigurasi route; semua page dipisah supaya ukuran bundle tetap terukur
/// dan transisi mudah dikontrol.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const NotesPage()),
      GoRoute(
        path: '/editor/:id',
        builder: (_, state) =>
            NoteEditorPage(noteId: state.pathParameters['id'] ?? 'new'),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    ],
  );
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Baca preferensi sebelum runApp supaya tema gelap/terang tidak flash.
  final prefs = PrefsRepository();
  final initialTheme = await prefs.readThemeMode();
  await prefs.writeLastOpened(DateTime.now());

  runApp(
    ProviderScope(
      overrides: [
        prefsRepositoryProvider.overrideWithValue(prefs),
        themeModeProvider.overrideWith(
          () => ThemeModeController(initial: initialTheme),
        ),
      ],
      child: const OfflineNotesApp(),
    ),
  );
}

/// Root aplikasi. MaterialApp.router supaya go_router menangani navigasi.
class OfflineNotesApp extends ConsumerWidget {
  const OfflineNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Offline Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return _AppWrapper(child: child);
      },
    );
  }
}

/// Wrapper yang secara otomatis membuka sheet konflik saat terdeteksi ada
/// catatan `conflicted`. Pengecekan dilakukan di atas semua layar.
class _AppWrapper extends ConsumerWidget {
  const _AppWrapper({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<Note>>>(conflictedNotesProvider, (_, next) {
      final notes = next.value;
      if (notes == null || notes.isEmpty) return;
      final fresh = ref
          .read(announcedConflictIdsProvider.notifier)
          .markSeen(notes.map((note) => note.id).nonNulls.toSet());
      if (fresh.isEmpty) return;

      // Ditunda satu frame supaya aman membuka sheet dari dalam listener
      // (listener bisa terpanggil saat sedang build).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigatorContext = rootNavigatorKey.currentContext;
        if (navigatorContext == null) return;
        showConflictResolutionSheet(navigatorContext, ref);
      });
    });

    return child ?? const SizedBox.shrink();
  }
}

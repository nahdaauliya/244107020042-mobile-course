import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/widgets/note_tile.dart';
import '../../../ui/widgets/status_widgets.dart';
import '../application/note_providers.dart';
import '../domain/note.dart';
import 'note_editor_page.dart';
import 'settings_page.dart';

/// Halaman daftar catatan.
///
/// Prinsip tampilannya: sumber data tunggal adalah cache SQLite. Halaman ini
/// tidak pernah menunggu jaringan, sehingga isinya sama persis online maupun
/// offline — perbedaan hanya terlihat di banner dan badge.
class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final pending = ref.watch(pendingUploadCountProvider).value ?? 0;
    final cache = ref.watch(cacheStatusProvider).value;
    final lastOpened = ref.watch(lastOpenedAtProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Offline'),
        actions: [
          IconButton(
            tooltip: isOnline ? 'Sinkronkan sekarang' : 'Sinkron (mode pesawat)',
            onPressed: () => syncAndReport(context, ref),
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: themeMode == ThemeMode.dark
                ? 'Beralih ke mode terang'
                : 'Beralih ke mode gelap',
            onPressed: () => ref.read(themeModeProvider.notifier).toggleDark(),
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isOnline) OfflineBanner(pendingUploads: pending),
          StatusStrip(
            noteCount: cache?.noteCount ?? notesAsync.value?.length ?? 0,
            pendingUploads: pending,
            lastPulledAt: cache?.lastSyncedAt ?? cache?.lastPulledAt,
            lastOpenedAt: lastOpened,
          ),
          Expanded(
            child: notesAsync.when(
              data: (notes) => _NoteList(notes: notes),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _LoadError(error: error),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Catatan baru',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NoteEditorPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NoteList extends ConsumerWidget {
  const _NoteList({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (notes.isEmpty) return const EmptyState();
    return RefreshIndicator(
      // Tarik-ke-bawah = sinkron manual. Aman saat offline: repository
      // mengembalikan laporan "offline", bukan exception.
      onRefresh: () => syncAndReport(context, ref),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: notes.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final note = notes[index];
          return NoteTile(
            note: note,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NoteEditorPage(noteId: note.id),
              ),
            ),
            onDelete: () => confirmDelete(context, ref, note),
          );
        },
      ),
    );
  }
}

/// Hapus dengan konfirmasi. Penghapusan bersifat *soft*: barisnya tetap ada di
/// SQLite sebagai tombstone supaya penghapusannya bisa ikut dikirim ke server.
Future<void> confirmDelete(BuildContext context, WidgetRef ref, Note note) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Hapus catatan?'),
      content: Text('"${note.displayTitle}" akan dihapus dan antre untuk '
          'disinkronkan ke server.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(notesProvider.notifier).deleteNote(note.id);
}

/// Jalankan sinkron lalu tampilkan ringkasannya.
///
/// Tidak pernah melempar exception ke UI: repository mengembalikan laporan
/// "offline" bila tidak ada koneksi, jadi snackbar selalu punya pesan.
Future<void> syncAndReport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final report = await ref.read(syncProvider.notifier).sync();
  if (!context.mounted) return;

  messenger.hideCurrentSnackBar();
  if (report == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Sinkron gagal: tidak ada laporan')),
    );
    return;
  }
  final conflictNote = report.conflicts.isEmpty
      ? ''
      : ' · ${report.conflicts.length} konflik (${report.conflicts.first.outcomeLabel})';
  messenger.showSnackBar(
    SnackBar(content: Text('${report.headline}$conflictNote')),
  );
}

class _LoadError extends ConsumerWidget {
  const _LoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat catatan dari cache lokal',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => ref.read(notesProvider.notifier).reload(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
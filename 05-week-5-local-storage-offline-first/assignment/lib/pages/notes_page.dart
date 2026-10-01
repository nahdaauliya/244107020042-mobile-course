import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/local/note.dart';
import '../providers/app_providers.dart';
import '../widgets/conflict_sheet.dart';
import '../widgets/note_tile.dart';
import '../widgets/sync_banner.dart';

/// Layar utama: daftar catatan, badge dirty, dan banner status sinkron.
class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesControllerProvider);
    final counts = ref.watch(syncCountsProvider).value;

    // Cache-first: memicu penyegaran server di background setelah frame
    // pertama (isi SQLite) tampil. Hasilnya diabaikan di sini karena
    // `backgroundSyncProvider` sendiri yang menginvalidasi daftar.
    ref.watch(backgroundSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Notes'),
        actions: [
          if ((counts?.conflicted ?? 0) > 0)
            IconButton(
              tooltip: 'Selesaikan konflik',
              onPressed: () => showConflictResolutionSheet(context, ref),
              icon: Badge(
                label: Text('${counts!.conflicted}'),
                child: const Icon(Icons.call_split),
              ),
            ),
          IconButton(
            tooltip: 'Aktifkan / matikan mode pesawat',
            onPressed: () {
              final controller = ref.read(isOnlineProvider.notifier);
              if (ref.read(isOnlineProvider)) {
                controller.goOffline();
              } else {
                // Kembali online otomatis memicu backgroundSyncProvider
                // karena provider itu meng-watch status koneksi.
                controller.goOnline();
              }
            },
            icon: Icon(
              ref.watch(isOnlineProvider)
                  ? Icons.cloud_done_outlined
                  : Icons.airplanemode_active,
            ),
          ),
          IconButton(
            tooltip: 'Ganti tema terang / gelap',
            onPressed: () => ref.read(themeModeProvider.notifier).toggleDark(),
            icon: const Icon(Icons.dark_mode_outlined),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SyncBanner(onSync: () async => _sync(context, ref)),
          _LastOpenedLine(),
          Expanded(
            child: switch (notes) {
              AsyncData(:final value) when value.isEmpty => const _EmptyState(),
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: () => _sync(context, ref),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 96),
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final note = value[index];
                    return NoteTile(
                      key: ValueKey(note.id),
                      note: note,
                      onTap: () => context.push('/editor/${note.id}'),
                      onDelete: () => _confirmDelete(context, ref, note),
                    );
                  },
                ),
              ),
              AsyncError(:final error) => _ErrorState(error: '$error'),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/editor/new'),
        icon: const Icon(Icons.edit_outlined),
        label: Text('Catatan${_pendingSuffix(counts?.pending ?? 0)}'),
      ),
    );
  }

  /// Satu-satunya jalur sinkron penuh: invalidate provider background lalu
  /// tunggu hasilnya. Dengan begitu tombol, pull-to-refresh, dan penyegaran
  /// otomatis saat halaman dibuka semuanya lewat kode yang sama.
  static Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    ref.invalidate(backgroundSyncProvider);
    final report = await ref.read(backgroundSyncProvider.future);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(report.message)));
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: Text('"${note.title}" akan dihapus dari perangkat ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    final id = note.id;
    if (confirmed == true && id != null) {
      await ref.read(notesControllerProvider.notifier).removeNote(id);
    }
  }

  static String _pendingSuffix(int pending) =>
      pending == 0 ? '' : ' ($pending)';
}

/// Baris kecil "terakhir dibuka" - preferensi SharedPreferences yang harus
/// terlihat agar jelas bahwa preferensi memang terpakai, bukan sekadar disimpan.
class _LastOpenedLine extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastOpened = ref.watch(lastOpenedProvider).value;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          lastOpened == null
              ? 'Pemasangan baru - belum ada waktu dibuka sebelumnya.'
              : 'Terakhir dibuka ${formatNoteTimestamp(lastOpened)} '
                    '(${_dateTimeText(lastOpened)})',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  static String _dateTimeText(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('Belum ada catatan'),
            const SizedBox(height: 4),
            const Text(
              'Tekan tombol "Catatan" untuk menulis yang pertama. '
              'Semua disimpan di SQLite, jadi tetap ada saat offline.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text('Gagal memuat catatan dari penyimpanan lokal.'),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, maxLines: 4),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/note.dart';
import '../providers/app_providers.dart';
import '../widgets/sync_badge.dart';

/// Sheet untuk menyelesaikan konflik. Dipanggil saat ada catatan yang
/// `status == conflicted`. Pengguna harus memilih satu versi - tidak ada
/// "merge otomatis" di sini, sesuai aturan eksplisit.
Future<void> showConflictResolutionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final conflicts = ref.watch(conflictedNotesProvider).value;
  if (conflicts == null || conflicts.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konflik sinkron (${conflicts.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Server menyimpan versi yang lebih baru, dan versi lokal juga '
              'berubah. Pilih salah satu untuk diselesaikan.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final note in conflicts) ...[
              _ConflictTile(note: note),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    },
  );
}

class _ConflictTile extends ConsumerWidget {
  const _ConflictTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notesControllerProvider.notifier);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title.isEmpty ? '(tanpa judul)' : note.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SyncBadge(note: note),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.body.isEmpty ? 'Tanpa isi' : note.body,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (note.conflictNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note.conflictNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await controller.keepRemoteVersion(note.id!);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Pakai versi server'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await controller.keepLocalVersion(note.id!);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Pakai versi ini'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

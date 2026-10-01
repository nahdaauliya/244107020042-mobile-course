import 'package:flutter/material.dart';
import '../data/local/note.dart';

/// Satu baris daftar catatan: judul, cuplikan isi, waktu ubah, dan badge
/// "belum tersinkron" bila catatan masih `dirty`.
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
    this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      title: Text(
        note.title.isEmpty ? '(tanpa judul)' : note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                note.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatNoteTimestamp(note.updatedAt),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note.dirty) ...[
            const DirtyBadge(),
            const SizedBox(width: 8),
          ],
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus catatan',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// Badge penanda catatan yang belum berhasil dikirim ke server.
/// Dipakai bersama oleh [NoteTile] dan halaman detail.
class DirtyBadge extends StatelessWidget {
  const DirtyBadge({super.key, this.label = 'belum tersinkron'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: 'Belum tersinkron',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 14,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

String formatNoteTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} '
      '${two(local.hour)}:${two(local.minute)}';
}

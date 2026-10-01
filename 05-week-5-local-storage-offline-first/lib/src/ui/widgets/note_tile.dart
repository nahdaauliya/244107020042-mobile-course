import 'package:flutter/material.dart';

import '../../core/format/datetime_format.dart';
import '../../features/notes/domain/note.dart';
import 'status_widgets.dart';

/// Satu baris daftar catatan: judul, cuplikan isi, waktu ubah, dan badge
/// "belum sinkron" bila masih ada antrean unggah.
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
    final scheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      title: Text(
        note.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.preview.isNotEmpty)
              Text(
                note.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  formatRelative(note.updatedAt),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note.isDirty) const DirtyBadge(),
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
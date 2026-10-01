import 'package:flutter/material.dart';

import '../data/local/note.dart';
import 'sync_badge.dart';

/// Satu baris daftar catatan: judul, cuplikan isi, waktu relatif, dan badge sync.
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(
          note.title.isEmpty ? '(tanpa judul)' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              note.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SyncBadge(note: note),
                Text(
                  'Diubah ${formatNoteTimestamp(note.updatedAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Hapus catatan',
        ),
      ),
    );
  }
}

/// Format waktu ringkas dan aman secara lokal: "baru saja", "12 mnt lalu",
/// "kemarin", lalu tanggal lengkap untuk yang lebih lama.
String formatNoteTimestamp(DateTime at, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(at);

  if (diff.inSeconds < 60) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'kemarin';

  if (diff.inDays < 7) return '$diff hari lalu';

  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(at.day)} ${_monthShort[at.month - 1]} ${at.year}';
}

const List<String> _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

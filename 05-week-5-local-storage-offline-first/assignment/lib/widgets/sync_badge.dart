import 'package:flutter/material.dart';

import '../data/local/note.dart';

/// Badge kecil di kanan atas kartu: "Belum sinkron" atau "Konflik".
///
/// Sengaja tanpa ikon agar status terbaca sekilas dari teks, dan warnanya
/// mengikuti [ColorScheme] supaya otomatis kontras di tema terang maupun gelap.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (note.isConflicted) {
      return _Badge(
        label: 'Konflik',
        icon: Icons.call_split,
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      );
    }
    if (note.isDirty) {
      return _Badge(
        label: 'Belum sinkron',
        icon: Icons.cloud_upload_outlined,
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      );
    }
    return const _Badge(
      label: 'Tersinkron',
      icon: Icons.cloud_done_outlined,
      background: null,
      foreground: null,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = background ?? scheme.surfaceContainerHighest;
    final fg = foreground ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

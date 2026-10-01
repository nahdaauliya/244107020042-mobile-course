import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/sync_service.dart';
import '../providers/app_providers.dart';

/// Banner di atas daftar yang menandai kondisi offline-first.
///
/// Isinya sengaja menampilkan angka nyata (jumlah catatan menunggu unggah)
/// supaya bukti mode pesawat bisa dibaca langsung dari tangkapan layar:
/// offline -> "X catatan menunggu sinkron" dengan tombol Sync nonaktif.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key, required this.onSync});

  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    final counts = ref.watch(syncCountsProvider).value;
    final run = ref.watch(syncRunStatusProvider);

    final scheme = Theme.of(context).colorScheme;
    final background = online
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = online ? scheme.onSecondaryContainer : scheme.onSurface;

    final pending = counts?.pending ?? 0;
    final conflicted = counts?.conflicted ?? 0;

    final (String statusText, IconData icon) = switch ((online, run)) {
      (false, _) => ('Mode pesawat aktif', Icons.airplanemode_active),
      (true, SyncRunStatus.failed) => (
        'Server tidak bisa dihubungi',
        Icons.cloud_off,
      ),
      (true, SyncRunStatus.needsDecision) => (
        'Ada konflik perlu diputuskan',
        Icons.call_split,
      ),
      (true, SyncRunStatus.upToDate) when pending == 0 => (
        'Semua catatan tersinkron',
        Icons.cloud_done_outlined,
      ),
      _ => ('$pending catatan menunggu sinkron', Icons.cloud_upload_outlined),
    };

    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: foreground),
                  ),
                  Text(
                    _subtitle(online, pending, conflicted, run),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: foreground.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: online ? () => onSync() : null,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sinkron'),
            ),
          ],
        ),
      ),
    );
  }

  static String _subtitle(
    bool online,
    int pending,
    int conflicted,
    SyncRunStatus run,
  ) {
    if (!online) {
      return 'Menampilkan cache SQLite. Perubahan tetap tersimpan lokal.';
    }
    if (conflicted > 0) {
      return '$conflicted catatan menunggu keputusan, $pending lain menunggu unggah.';
    }
    if (run == SyncRunStatus.failed) {
      return 'Data lokal tetap utuh; coba lagi saat jaringan stabil.';
    }
    return 'Cache lokal ditampilkan, lalu disegarkan dari server.';
  }
}

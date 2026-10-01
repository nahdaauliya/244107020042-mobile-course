import 'package:flutter/material.dart';

import '../../core/format/datetime_format.dart';

/// Badge "belum sinkron" untuk satu catatan.
///
/// Elemen paling penting untuk membuktikan mode pesawat: selama catatan masih
/// punya perubahan lokal yang belum sampai ke server, badge ini menyala. Di
/// screenshot, badge inilah yang berubah antara sebelum dan sesudah sinkron.
class DirtyBadge extends StatelessWidget {
  const DirtyBadge({super.key, this.label = 'Belum sinkron'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.tertiary, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 13, color: scheme.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Banner yang muncul saat perangkat tidak daring.
///
/// Sifatnya informatif, bukan pemblokir: seluruh isi aplikasi tetap bisa dibaca
/// dan ditulis. Yang berubah hanya sumber datanya — cache lokal.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.pendingUploads});

  final int pendingUploads;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.airplanemode_active, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pendingUploads > 0
                  ? 'Mode pesawat · $pendingUploads catatan menunggu sinkron. '
                      'Semua data di bawah dibaca dari cache lokal.'
                  : 'Mode pesawat · menampilkan cache lokal.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Strip status di bawah app bar: usia cache, jumlah antrean, waktu pembukaan
/// terakhir. Baris ini yang membuat perilaku cache-first terlihat oleh pengguna
/// biasa, bukan cuma oleh mereka yang membuka log.
class StatusStrip extends StatelessWidget {
  const StatusStrip({
    super.key,
    required this.noteCount,
    required this.pendingUploads,
    required this.lastPulledAt,
    required this.lastOpenedAt,
  });

  final int noteCount;
  final int pendingUploads;
  final DateTime? lastPulledAt;
  final DateTime? lastOpenedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_outlined, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$noteCount catatan · sinkron terakhir ${formatAge(lastPulledAt)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (pendingUploads > 0)
                DirtyBadge(label: '$pendingUploads menunggu'),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.history, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lastOpenedAt == null
                      ? 'Sesi pertama'
                      : 'Terakhir dibuka ${formatRelative(lastOpenedAt)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String formatAge(DateTime? value) => formatRelative(value);

/// Layar kosong yang menjelaskan apa yang harus dilakukan, bukan sekadar
/// "tidak ada data".
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('Belum ada catatan', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Tekan + untuk membuat catatan. Penyimpanan berlangsung lokal '
              'lewat SQLite, jadi tetap bisa saat offline.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
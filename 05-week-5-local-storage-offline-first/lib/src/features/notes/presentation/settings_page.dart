import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/datetime_format.dart';
import '../../settings/application/settings_providers.dart';
import '../application/note_providers.dart';
import '../domain/conflict.dart';

/// Preferensi yang disimpan di `SharedPreferences`: tema, aturan konflik,
/// dan sakelar mode pesawat simulasi.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final strategy = ref.watch(conflictStrategyProvider);
    final simulateOffline = ref.watch(simulateOfflineProvider);
    final cache = ref.watch(cacheStatusProvider).value;
    final lastOpened = ref.watch(lastOpenedAtProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const _SectionHeader('Tampilan'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Sistem'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Terang'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Gelap'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).setMode(selection.first),
            ),
          ),

          const _SectionHeader('Koneksi'),
          SwitchListTile(
            value: simulateOffline,
            onChanged: (value) =>
                ref.read(simulateOfflineProvider.notifier).setOffline(value),
            secondary: const Icon(Icons.airplanemode_active),
            title: const Text('Mode pesawat (simulasi)'),
            subtitle: const Text(
              'Meniru efek mode pesawat sungguhan: sinkron berhenti dan seluruh '
              'data hanya dibaca dari cache SQLite.',
            ),
          ),

          const _SectionHeader('Aturan konflik sinkronisasi'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Dipakai hanya ketika perangkat ini dan server sama-sama '
              'mengubah catatan yang sama.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          RadioGroup<ConflictStrategy>(
            groupValue: strategy,
            onChanged: (value) {
              if (value != null) {
                ref.read(conflictStrategyProvider.notifier).setStrategy(value);
              }
            },
            child: Column(
              children: [
                for (final option in ConflictStrategy.values)
                  RadioListTile<ConflictStrategy>(
                    value: option,
                    title: Text(option.label),
                    subtitle: Text(option.description),
                  ),
              ],
            ),
          ),

          const _SectionHeader('Penyimpanan lokal'),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text('Catatan di SQLite: ${cache?.noteCount ?? '-'}'),
            subtitle: Text(
              'Menunggu sinkron: ${cache?.pendingUploads ?? '-'} · '
              'Sync terakhir: ${formatDateTime(cache?.lastSyncedAt)}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Terakhir dibuka'),
            subtitle: Text(formatDateTime(lastOpened)),
          ),
          ListTile(
            leading: const Icon(Icons.settings_suggest_outlined),
            title: const Text('Dokumentasi'),
            subtitle: const Text(
              'Aturan konflik, tabel perbandingan storage, dan keputusan '
              'arsitektur ada di folder docs/ pada repository.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
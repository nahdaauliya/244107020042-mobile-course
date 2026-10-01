import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../widgets/note_tile.dart';

/// Pengaturan: tema gelap/terang dan waktu terakhir dibuka.
///
/// Keduanya dibaca dari SharedPreferences, ditulis ulang setiap kali diubah,
/// dan ditampilkan kembali apa adanya supaya jelas preferensi tidak hilang
/// saat aplikasi ditutup.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final lastOpened = ref.watch(lastOpenedProvider).value;
    final online = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const _SectionTitle('Tampilan'),
          RadioGroup<ThemeModeOption>(
            groupValue: ThemeModeOption.from(themeMode),
            onChanged: (option) {
              if (option == null) return;
              ref.read(themeModeProvider.notifier).setMode(option.mode);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeModeOption>(
                  value: ThemeModeOption.system,
                  title: Text('Ikuti sistem'),
                ),
                RadioListTile<ThemeModeOption>(
                  value: ThemeModeOption.light,
                  title: Text('Terang'),
                ),
                RadioListTile<ThemeModeOption>(
                  value: ThemeModeOption.dark,
                  title: Text('Gelap'),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          const _SectionTitle('Penyimpanan & jaringan'),
          ListTile(
            leading: Icon(online ? Icons.wifi : Icons.airplanemode_active),
            title: const Text('Mode pesawat'),
            subtitle: Text(
              online
                  ? 'Normal - sinkron berjalan otomatis setelah cache tampil.'
                  : 'Aktif - aplikasi hanya membaca dan menulis SQLite lokal.',
            ),
            trailing: Switch(
              value: !online,
              onChanged: (offline) {
                final connectivity = ref.read(isOnlineProvider.notifier);
                if (offline) {
                  connectivity.goOffline();
                } else {
                  // Kembali online memicu ulang backgroundSyncProvider lewat
                  // perubahan status koneksi.
                  connectivity.goOnline();
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Terakhir dibuka'),
            subtitle: Text(
              lastOpened == null
                  ? 'Belum pernah tercatat.'
                  : '${_stamp(lastOpened)} (${formatNoteTimestamp(lastOpened)})',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Database lokal'),
            subtitle: const Text(
              'offline_notes.db - tabel notes, urut updated_at terbaru dulu.',
            ),
          ),
        ],
      ),
    );
  }

  static String _stamp(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} '
        '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}

/// Opsi tema yang bisa dipilih pengguna, dipisah dari `ThemeMode` agar
/// `RadioListTile` punya tipe stabil untuk perbandingan.
enum ThemeModeOption {
  system(ThemeMode.system, 'Ikuti sistem'),
  light(ThemeMode.light, 'Terang'),
  dark(ThemeMode.dark, 'Gelap');

  const ThemeModeOption(this.mode, this.label);

  final ThemeMode mode;
  final String label;

  static ThemeModeOption from(ThemeMode mode) {
    return ThemeModeOption.values.firstWhere(
      (option) => option.mode == mode,
      orElse: () => ThemeModeOption.system,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/stats_notifier.dart';

/// StatsPage menggunakan ConsumerWidget karena halaman ini
/// perlu membaca state dari Riverpod.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Membaca state dari statsProvider.
    //
    // Karena provider menggunakan AsyncNotifierProvider,
    // state yang diterima berupa AsyncValue<List<String>>.
    final statsState = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),

      // AsyncValue.when() digunakan untuk menangani 3 kondisi utama:
      //
      // 1. loading -> ketika data sedang diambil
      // 2. error   -> ketika pengambilan data gagal
      // 3. data    -> ketika pengambilan data berhasil
      body: statsState.when(
        // ============================
        // KONDISI LOADING
        // ============================
        loading: () {
          // Menampilkan spinner selama proses mengambil data.
          return const Center(
            child: CircularProgressIndicator(),
          );
        },

        // ============================
        // KONDISI ERROR
        // ============================
        error: (error, stackTrace) {
          return Center(
            child: Column(
              // Membuat isi berada di tengah secara horizontal.
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Gagal mengambil data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Menampilkan pesan error dari notifier.
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Tombol untuk mengambil data kembali.
                ElevatedButton(
                  onPressed: () {
                    // Memanggil method retry() dari notifier.
                    ref.read(statsProvider.notifier).retry();
                  },
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        },

        // ============================
        // KONDISI SUCCESS
        // ============================
        data: (statistics) {
          // Jika data berhasil diperoleh,
          // tampilkan dalam bentuk ListView.
          return ListView.builder(
            padding: const EdgeInsets.all(16),

            // Jumlah item mengikuti jumlah data yang diperoleh.
            itemCount: statistics.length,

            itemBuilder: (context, index) {
              // Mengambil data statistik berdasarkan index.
              final statistic = statistics[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  // Nomor statistik.
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),

                  // Isi statistik.
                  title: Text(statistic),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
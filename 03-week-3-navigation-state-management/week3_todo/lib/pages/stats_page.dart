import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/stats_notifier.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final statsState = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),

      body: statsState.when(

        loading: () {
          // Menampilkan spinner selama proses mengambil data.
          return const Center(
            child: CircularProgressIndicator(),
          );
        },


        error: (error, stackTrace) {
          return Center(
            child: Column(
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

                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () {

                    ref.read(statsProvider.notifier).retry();
                  },
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        },

        data: (statistics) {

          return ListView.builder(
            padding: const EdgeInsets.all(16),


            itemCount: statistics.length,

            itemBuilder: (context, index) {

              final statistic = statistics[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),

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
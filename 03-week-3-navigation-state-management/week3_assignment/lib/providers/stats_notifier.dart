import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider yang digunakan oleh UI untuk mendapatkan state statistik.
///
/// AsyncNotifierProvider otomatis menangani state:
/// - AsyncLoading
/// - AsyncData
/// - AsyncError
final statsProvider =
    AsyncNotifierProvider<StatsNotifier, List<String>>(StatsNotifier.new);

/// Notifier yang bertugas mengambil data statistik.
///
/// Tipe data yang dikelola adalah:
/// List<String>
class StatsNotifier extends AsyncNotifier<List<String>> {
  /// Random digunakan untuk mensimulasikan kemungkinan request gagal.
  ///
  /// Dibuat sebagai parameter agar pada unit test kita bisa
  /// menggunakan Random palsu sehingga hasil test konsisten.
  StatsNotifier({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Method build() dijalankan pertama kali ketika provider digunakan.
  ///
  /// Kita gunakan method ini untuk mengambil data statistik.
  @override
  Future<List<String>> build() async {
    return _getStatistics();
  }

  /// Mensimulasikan proses mengambil data dari server/API.
  Future<List<String>> _getStatistics() async {
    // Mensimulasikan waktu loading selama 2 detik.
    await Future.delayed(const Duration(seconds: 2));

    // Menghasilkan angka 0 sampai 99.
    //
    // Jika hasil < 30, maka dianggap request gagal.
    // Artinya kemungkinan gagal adalah sekitar 30%.
    if (_random.nextInt(100) < 30) {
      throw Exception('Gagal mengambil data statistik.');
    }

    // Jika tidak gagal, kembalikan 3 data statistik.
    return [
      'Total Pengguna: 1.250',
      'Pengguna Aktif: 875',
      'Total Transaksi: 3.420',
    ];
  }

  /// Digunakan ketika user menekan tombol "Coba Lagi".
  ///
  /// invalidateSelf() akan meminta Riverpod menjalankan kembali
  /// proses build() sehingga data diambil ulang.
  void retry() {
    ref.invalidateSelf();
  }
}
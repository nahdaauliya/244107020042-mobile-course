import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';


final statsProvider =
    AsyncNotifierProvider<StatsNotifier, List<String>>(StatsNotifier.new);

class StatsNotifier extends AsyncNotifier<List<String>> {
  StatsNotifier({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  Future<List<String>> build() async {
    return _getStatistics();
  }

  Future<List<String>> _getStatistics() async {

    await Future.delayed(const Duration(seconds: 2));


    if (_random.nextInt(100) < 30) {
      throw Exception('Gagal mengambil data statistik.');
    }

    return [
      'Total Pengguna: 1.250',
      'Pengguna Aktif: 875',
      'Total Transaksi: 3.420',
    ];
  }

  void retry() {
    ref.invalidateSelf();
  }
}
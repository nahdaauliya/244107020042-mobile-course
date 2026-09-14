import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../lib/providers/stats_notifier.dart';

/// Random palsu untuk unit testing.
///
/// nextInt() akan selalu mengembalikan nilai yang kita tentukan.
class FakeRandom implements Random {
  FakeRandom(this.value);

  final int value;

  @override
  int nextInt(int max) {
    return value;
  }

  // Method-method berikut diperlukan karena Random
  // memiliki beberapa method lain.
  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => value.toDouble();

}

void main() {
  group('StatsNotifier', () {
    test(
      'mengembalikan 3 data statistik ketika request berhasil',
      () async {
        // Nilai 50 berarti tidak masuk kondisi gagal (< 30).
        final notifier = StatsNotifier(
          random: FakeRandom(50),
        );

        // build() akan mengambil data statistik.
        final result = await notifier.build();

        // Pastikan terdapat 3 data statistik.
        expect(result.length, 3);

        // Pastikan data pertama sesuai.
        expect(
          result[0],
          'Total Pengguna: 1.250',
        );

        // Pastikan data kedua sesuai.
        expect(
          result[1],
          'Pengguna Aktif: 875',
        );

        // Pastikan data ketiga sesuai.
        expect(
          result[2],
          'Total Transaksi: 3.420',
        );
      },
    );

    test(
      'melempar error ketika request gagal',
      () async {
        // Nilai 10 berarti masuk kondisi gagal karena < 30.
        final notifier = StatsNotifier(
          random: FakeRandom(10),
        );

        // build() seharusnya menghasilkan error.
        await expectLater(
          notifier.build(),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}
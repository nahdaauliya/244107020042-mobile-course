import 'package:flutter_test/flutter_test.dart';
import 'package:campus_notify/ai/chat_validator.dart';

void main() {
  group('ChatValidator', () {
    group('Validasi pesan kosong', () {
      test('Menolak pesan kosong', () {
        expect(
          () => ChatValidator.validate(''),
          throwsA(
            predicate(
              (e) => e.toString().contains('Pertanyaan tidak boleh kosong.'),
            ),
          ),
        );
      });

      test('Menolak pesan yang hanya berisi spasi', () {
        expect(() => ChatValidator.validate('     '), throwsException);
      });
    });

    group('Validasi data sensitif', () {
      test('Menolak pesan yang mengandung NIK', () {
        expect(
          () => ChatValidator.validate('NIK saya 1234567890123456'),
          throwsA(predicate((e) => e.toString().contains('berisi NIK'))),
        );
      });

      test('Menolak pesan yang mengandung nomor telepon', () {
        expect(
          () => ChatValidator.validate('Nomor saya 081234567890'),
          throwsA(predicate((e) => e.toString().contains('nomor telepon'))),
        );
      });
    });

    group('Validasi pesan normal', () {
      test('Menerima pesan yang valid', () {
        final result = ChatValidator.validate('Apa itu Flutter?');

        expect(result, 'Apa itu Flutter?');
      });

      test('Menghapus spasi di awal dan akhir pesan', () {
        final result = ChatValidator.validate('  Halo AI  ');

        expect(result, 'Halo AI');
      });
    });
  });
}

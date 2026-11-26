import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_ai_repository.dart';

void main() {
  group('FakeAiRepository', () {
    late FakeAiRepository repository;

    setUp(() {
      repository = FakeAiRepository();
    });

    test('Mengembalikan jawaban ketika request berhasil', () async {
      final result = await repository.ask('Apa itu Flutter?');

      expect(result, 'Halo! Saya AI Assistant.');
      expect(repository.askCallCount, 1);
      expect(repository.lastQuestion, 'Apa itu Flutter?');
    });

    test('Menghasilkan error ketika request gagal', () async {
      repository.shouldFail = true;

      await expectLater(repository.ask('Apa itu Flutter?'), throwsException);

      expect(repository.askCallCount, 1);
    });

    test('Mengembalikan jawaban sesuai konfigurasi fake', () async {
      repository.response = 'Flutter adalah framework UI.';

      final result = await repository.ask('Apa itu Flutter?');

      expect(result, 'Flutter adalah framework UI.');
    });
  });
}

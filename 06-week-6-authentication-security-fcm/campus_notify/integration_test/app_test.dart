import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:campus_notify/main.dart';

import '../test/fakes/fake_ai_repository.dart';

import 'package:material_ui/material_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Pengguna berhasil mengirim pesan dan menerima respons AI', (
    tester,
  ) async {
    final fakeRepository = FakeAiRepository()
      ..response = 'Halo! Saya AI Assistant.';

    await tester.pumpWidget(MyApp(repository: fakeRepository));

    await tester.pumpAndSettle();

    // Pastikan halaman AI Chat terbuka.
    expect(find.text('AI Chat'), findsOneWidget);

    // Pengguna mengetik pesan.
    final inputFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Tulis pesan...',
    );

    await tester.enterText(inputFinder, 'Halo AI');

    // Pengguna mengirim pesan.
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // Pastikan pesan dan respons AI muncul.
    expect(find.text('Halo AI'), findsOneWidget);
    expect(find.text('Halo! Saya AI Assistant.'), findsOneWidget);

    // Pastikan repository menerima satu permintaan.
    expect(fakeRepository.askCallCount, 1);
    expect(fakeRepository.lastQuestion, 'Halo AI');
  });
}

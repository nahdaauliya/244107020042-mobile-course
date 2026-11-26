import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_notify/features/chat_screen.dart';

import '../fakes/fake_ai_repository.dart';

void main() {
  Finder chatInputFinder() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Tulis pesan...',
    );
  }

  group('ChatScreen Widget Test', () {
    late FakeAiRepository fakeRepository;

    Future<void> createChatScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ChatScreen(repository: fakeRepository)),
      );

      await tester.pumpAndSettle();
    }

    setUp(() {
      fakeRepository = FakeAiRepository();
    });

    testWidgets('Menampilkan tampilan awal AI Chat', (tester) async {
      await createChatScreen(tester);

      expect(find.text('AI Chat'), findsOneWidget);
      expect(find.text('Mulai percakapan dengan AI'), findsOneWidget);
      expect(chatInputFinder(), findsOneWidget);
    });

    testWidgets('Input kosong tidak mengirim permintaan', (tester) async {
      await createChatScreen(tester);

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(fakeRepository.askCallCount, 0);
      expect(find.text('Mulai percakapan dengan AI'), findsOneWidget);
    });

    testWidgets('Pesan berhasil dikirim dan jawaban AI ditampilkan', (
      tester,
    ) async {
      fakeRepository.response = 'Halo! Ada yang bisa saya bantu?';

      await createChatScreen(tester);

      await tester.enterText(chatInputFinder(), 'Halo AI');

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(fakeRepository.askCallCount, 1);
      expect(fakeRepository.lastQuestion, 'Halo AI');
      expect(find.text('Halo AI'), findsOneWidget);
      expect(find.text('Halo! Ada yang bisa saya bantu?'), findsOneWidget);
    });

    testWidgets('Kegagalan API menampilkan pilihan Mode Offline', (
      tester,
    ) async {
      fakeRepository.shouldFail = true;

      await createChatScreen(tester);

      await tester.enterText(chatInputFinder(), 'Halo AI');

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Layanan AI Bermasalah'), findsOneWidget);

      await tester.tap(find.text('Mode Offline'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Mode offline: layanan AI tidak tersedia.'),
        findsOneWidget,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:campus_notify/main.dart';

void main() {
  testWidgets('App renders AI chat page by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.pumpAndSettle();

    expect(find.text('AI Chat'), findsOneWidget);
  });
}

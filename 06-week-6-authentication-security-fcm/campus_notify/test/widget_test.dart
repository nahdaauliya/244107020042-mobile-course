import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_notify/main.dart';

void main() {
  testWidgets('App renders login page by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Campus Notify - Login'), findsOneWidget);
  });
}
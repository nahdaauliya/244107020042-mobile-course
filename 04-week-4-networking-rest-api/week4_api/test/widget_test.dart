import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:week4_api/main.dart';

void main() {
  testWidgets('App builds and renders the posts home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Posts Paged'), findsOneWidget);
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:week4_api/data/models/post.dart';
import 'package:week4_api/widgets/post_tile.dart';

void main() {
  const post = Post(
    userId: 1,
    id: 42,
    title: 'Refactor the API client',
    body:
        'Move the repository behind an interface so tests can swap in '
        'a fake implementation without touching the network.',
  );

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  testWidgets('renders id, title, and body preview',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const PostTile(post: post)));

    expect(find.text('42'), findsOneWidget);
    expect(find.text(post.title), findsOneWidget);
    expect(find.text(post.body), findsOneWidget);
  });

  testWidgets('invokes onTap when tapped',
      (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(PostTile(
      post: post,
      onTap: () => tapped = true,
    )));

    await tester.tap(find.byType(PostTile));
    expect(tapped, isTrue);
  });
}
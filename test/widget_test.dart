import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skutla/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const SkutlaApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

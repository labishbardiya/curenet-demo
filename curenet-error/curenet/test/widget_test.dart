import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:curenet/main.dart';          // ← This imports our CureNetApp

void main() {
  testWidgets('CureNet app launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const CureNetApp());

    // Basic smoke test - checks if splash screen appears
    expect(find.text('CureNet'), findsOneWidget);
  });
}
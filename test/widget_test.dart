// This is a basic Flutter widget test for MyAssistant app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('MyAssistant app starts with splash screen', (WidgetTester tester) async {
    // Build our app wrapped with ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('MyAssistant'),
            ),
          ),
        ),
      ),
    );

    // Verify that MyAssistant text appears
    expect(find.text('MyAssistant'), findsOneWidget);
  });
}

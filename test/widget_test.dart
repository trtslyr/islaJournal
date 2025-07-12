// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isla_journal/main.dart';


void main() {
  testWidgets('Isla Journal app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const IslaJournalApp());

    // Just pump once to render the initial frame
    await tester.pump();

    // Verify that our app loads with the correct title.
    expect(find.text('Isla Journal'), findsOneWidget);
    
    // Verify that we have basic UI structure
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}

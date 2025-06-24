// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sensing_collector/main.dart';

void main() {
  testWidgets('App starts and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: SensingCollectorApp()));

    // Verify that the home screen is displayed
    expect(find.text('Sensing Collector'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);

    // Verify that status card is present
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Ready to collect'), findsOneWidget);
  });

  testWidgets('Navigation to settings works', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SensingCollectorApp()));

    // Tap the settings icon
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Verify that settings screen is opened
    expect(find.text('Settings'), findsOneWidget);
  });
}

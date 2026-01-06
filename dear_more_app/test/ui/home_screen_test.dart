import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dear_more/ui/home_screen.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('shows status card', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()),
      );

      // Look for key elements
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('has app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()),
      );

      expect(find.widgetWithText(AppBar, 'Dear More'), findsOneWidget);
    });

    testWidgets('shows statistics card', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()),
      );

      await tester.pumpAndSettle();

      // Should have multiple cards for status, stats, etc.
      expect(find.byType(Card), findsAtLeastNWidgets(1));
    });
  });
}

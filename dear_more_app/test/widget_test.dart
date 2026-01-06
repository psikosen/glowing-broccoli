import 'package:flutter_test/flutter_test.dart';
import 'package:dear_more/main.dart';

void main() {
  testWidgets('App starts and shows navigation', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DearMoreApp());

    // Verify app loaded
    expect(find.text('Dear More'), findsWidgets);
  });
}

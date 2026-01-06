import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dear_more/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dear More Integration Tests', () {
    testWidgets('app starts and shows main navigation',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify bottom navigation is visible
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Memory'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('can navigate between screens', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap Memory tab
      await tester.tap(find.text('Memory'));
      await tester.pumpAndSettle();

      // Should show memory screen
      expect(find.text('Memory Bank'), findsOneWidget);

      // Tap Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Should show settings screen
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
    });
  });
}

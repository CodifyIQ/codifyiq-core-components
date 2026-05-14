import 'package:codifyiq_core_components_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Example app boots and shows the widget catalog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Material Design Widget Catalog'), findsOneWidget);
  });
}

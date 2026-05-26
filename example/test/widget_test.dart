import 'package:codifyiq_components_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    // AdaptiveTheme reads SharedPreferencesAsync during initState; provide an
    // in-memory implementation so the app can boot under the test binding.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Example app boots and shows the widget catalog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Material Design Widget Catalog'), findsOneWidget);
  });
}

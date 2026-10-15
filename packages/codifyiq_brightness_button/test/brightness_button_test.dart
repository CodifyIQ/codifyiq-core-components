import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Hosts [button] in an app bar under an [AdaptiveTheme].
Widget _host(BrightnessButton button) {
  return AdaptiveTheme(
    light: ThemeData(),
    dark: ThemeData(brightness: Brightness.dark),
    initial: AdaptiveThemeMode.light,
    builder: (theme, darkTheme) => MaterialApp(
      theme: theme,
      darkTheme: darkTheme,
      home: Scaffold(appBar: AppBar(actions: [button])),
    ),
  );
}

Finder _checkOn(String label) => find.descendant(
  of: find.widgetWithText(MenuItemButton, label),
  matching: find.byIcon(Icons.check),
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('switches to Dark and checks it', (tester) async {
    await tester.pumpWidget(_host(const BrightnessButton()));
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(_checkOn('Light'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final mode = AdaptiveTheme.of(tester.element(find.byType(IconButton))).mode;
    expect(mode, AdaptiveThemeMode.dark);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(_checkOn('Dark'), findsOneWidget);
    expect(_checkOn('Light'), findsNothing);
  });

  testWidgets('applies label and tooltip overrides', (tester) async {
    await tester.pumpWidget(
      _host(
        const BrightnessButton(
          tooltip: 'Thème',
          lightLabel: 'Clair',
          darkLabel: 'Sombre',
          systemLabel: 'Système',
        ),
      ),
    );
    expect(find.byTooltip('Thème'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('Clair'), findsOneWidget);
    expect(find.text('Sombre'), findsOneWidget);
    expect(find.text('Système'), findsOneWidget);
  });
}

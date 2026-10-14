import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Hosts a [BrightnessSubmenu] inside an app's own [MenuAnchor].
Widget _host() {
  return AdaptiveTheme(
    light: ThemeData(),
    dark: ThemeData(brightness: Brightness.dark),
    initial: AdaptiveThemeMode.light,
    builder: (theme, darkTheme) => MaterialApp(
      theme: theme,
      darkTheme: darkTheme,
      home: Scaffold(
        body: MenuAnchor(
          menuChildren: const [BrightnessSubmenu()],
          builder: (context, controller, child) => TextButton(
            onPressed: controller.open,
            child: const Text('Account'),
          ),
        ),
      ),
    ),
  );
}

AdaptiveThemeMode _mode(WidgetTester tester) =>
    AdaptiveTheme.of(tester.element(find.text('Account'))).mode;

Finder _submenuIcon(IconData icon) => find.descendant(
  of: find.widgetWithText(SubmenuButton, 'Theme'),
  matching: find.byIcon(icon),
);

Future<void> _openSubmenu(WidgetTester tester) async {
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Theme'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('switches to Dark from inside a host menu', (tester) async {
    await tester.pumpWidget(_host());
    await _openSubmenu(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(_mode(tester), AdaptiveThemeMode.dark);
  });

  testWidgets('checks the active mode', (tester) async {
    await tester.pumpWidget(_host());
    await _openSubmenu(tester);

    Finder checkOn(String label) => find.descendant(
      of: find.widgetWithText(MenuItemButton, label),
      matching: find.byIcon(Icons.check),
    );
    expect(checkOn('Light'), findsOneWidget);
    expect(checkOn('Dark'), findsNothing);
    expect(checkOn('System'), findsNothing);
  });

  testWidgets('leading icon follows the mode', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(_submenuIcon(Icons.light_mode_outlined), findsOneWidget);

    AdaptiveTheme.of(tester.element(find.text('Account'))).setDark();
    await tester.pumpAndSettle();

    expect(_submenuIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(_submenuIcon(Icons.light_mode_outlined), findsNothing);
  });
}

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

/// A button that allows the user to select the application's theme mode.
///
/// This button displays an icon representing the current theme mode (light, dark,
/// or system default). When pressed, it opens a menu with options to switch
/// between Light, Dark, and System theme modes.
class BrightnessButton extends StatelessWidget {
  /// Creates a [BrightnessButton].
  const BrightnessButton({super.key});

  @override
  Widget build(BuildContext context) {
    final adaptiveTheme = AdaptiveTheme.of(context);

    IconData getIcon() {
      switch (adaptiveTheme.mode) {
        case AdaptiveThemeMode.light:
          return Icons.light_mode_outlined;
        case AdaptiveThemeMode.dark:
          return Icons.dark_mode_outlined;
        case AdaptiveThemeMode.system:
        default:
          return Icons.brightness_auto;
      }
    }

    return MenuAnchor(
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        return IconButton(
          icon: Icon(
            getIcon(),
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
          tooltip: 'Switch Brightness Theme',
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
      menuChildren: <Widget>[
        MenuItemButton(
          onPressed: () => adaptiveTheme.setLight(),
          leadingIcon: const Icon(Icons.light_mode_outlined),
          trailingIcon: adaptiveTheme.mode == AdaptiveThemeMode.light
              ? const Icon(Icons.check)
              : null,
          child: const Text('Light'),
        ),
        MenuItemButton(
          onPressed: () => adaptiveTheme.setDark(),
          leadingIcon: const Icon(Icons.dark_mode_outlined),
          trailingIcon: adaptiveTheme.mode == AdaptiveThemeMode.dark
              ? const Icon(Icons.check)
              : null,
          child: const Text('Dark'),
        ),
        MenuItemButton(
          onPressed: () => adaptiveTheme.setSystem(),
          leadingIcon: const Icon(Icons.brightness_auto),
          trailingIcon:
              adaptiveTheme.mode.isSystem ? const Icon(Icons.check) : null,
          child: const Text('System'),
        ),
      ],
    );
  }
}

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Returns the icon that represents [mode].
///
/// Shared by [brightnessMenuItems] and the widgets built on it so every
/// surface shows the same icon for the same mode. Not exported from the
/// package barrel.
IconData brightnessModeIcon(AdaptiveThemeMode mode) {
  switch (mode) {
    case AdaptiveThemeMode.light:
      return Icons.light_mode_outlined;
    case AdaptiveThemeMode.dark:
      return Icons.dark_mode_outlined;
    case AdaptiveThemeMode.system:
      return Icons.brightness_auto;
  }
}

/// Builds the Light / Dark / System [MenuItemButton]s for inline use in any
/// menu's children.
///
/// Spread the result into an existing `MenuAnchor`'s `menuChildren` (or a
/// [SubmenuButton]'s `menuChildren`) to offer the theme choice without a
/// separate button:
///
/// ```dart
/// MenuAnchor(
///   menuChildren: [
///     MenuItemButton(onPressed: signOut, child: const Text('Sign out')),
///     ...brightnessMenuItems(context),
///   ],
///   builder: ...,
/// );
/// ```
///
/// The mode is read and set through `AdaptiveTheme.of(context)`, so [context]
/// must sit below an `AdaptiveTheme`. The active mode shows a trailing check.
///
/// [lightLabel], [darkLabel], and [systemLabel] override the item labels,
/// e.g. for localization.
List<Widget> brightnessMenuItems(
  BuildContext context, {
  String lightLabel = 'Light',
  String darkLabel = 'Dark',
  String systemLabel = 'System',
}) {
  final adaptiveTheme = AdaptiveTheme.of(context);
  final mode = adaptiveTheme.mode;

  Widget item(AdaptiveThemeMode itemMode, String label, VoidCallback onSet) {
    return MenuItemButton(
      onPressed: onSet,
      leadingIcon: Icon(brightnessModeIcon(itemMode)),
      trailingIcon: mode == itemMode ? const Icon(Icons.check) : null,
      child: Text(label),
    );
  }

  return [
    item(AdaptiveThemeMode.light, lightLabel, adaptiveTheme.setLight),
    item(AdaptiveThemeMode.dark, darkLabel, adaptiveTheme.setDark),
    item(AdaptiveThemeMode.system, systemLabel, adaptiveTheme.setSystem),
  ];
}

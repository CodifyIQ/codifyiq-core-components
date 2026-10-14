import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:codifyiq_brightness_button/src/brightness_menu_items.dart';
import 'package:material_ui/material_ui.dart';

/// A "Theme" submenu offering the Light / Dark / System choice inside an
/// existing menu.
///
/// Place it in any `MenuAnchor`'s `menuChildren` (e.g. an account or
/// overflow menu) instead of adding a separate [BrightnessButton]:
///
/// ```dart
/// MenuAnchor(
///   menuChildren: const [BrightnessSubmenu()],
///   builder: ...,
/// );
/// ```
///
/// The leading icon reflects the current mode, and the active mode shows a
/// trailing check. Requires an `AdaptiveTheme` ancestor.
class BrightnessSubmenu extends StatelessWidget {
  /// Creates a [BrightnessSubmenu].
  ///
  /// [label] is the submenu's own label; [lightLabel], [darkLabel], and
  /// [systemLabel] label its items.
  const BrightnessSubmenu({
    super.key,
    this.label = 'Theme',
    this.lightLabel = 'Light',
    this.darkLabel = 'Dark',
    this.systemLabel = 'System',
  });

  /// Label of the submenu entry in the host menu.
  final String label;

  /// Label of the Light item.
  final String lightLabel;

  /// Label of the Dark item.
  final String darkLabel;

  /// Label of the System item.
  final String systemLabel;

  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      leadingIcon: Icon(brightnessModeIcon(AdaptiveTheme.of(context).mode)),
      menuChildren: brightnessMenuItems(
        context,
        lightLabel: lightLabel,
        darkLabel: darkLabel,
        systemLabel: systemLabel,
      ),
      child: Text(label),
    );
  }
}

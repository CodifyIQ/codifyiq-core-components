import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

/// A button that allows the user to select the application's theme mode.
///
/// This button displays an icon representing the current theme mode (light, dark,
/// or system default). When pressed, it opens a menu with options to switch
/// between Light, Dark, and System theme modes.
///
/// The dropdown is rendered as a Material 3 surface (rounded corners,
/// elevation, surface tint) with a configurable inset from the trailing
/// viewport edge so it does not sit flush against the screen.
class BrightnessButton extends StatelessWidget {
  /// Creates a [BrightnessButton].
  const BrightnessButton({
    super.key,
    this.iconColor,
    this.menuAlignmentOffset = const Offset(0, 8),
    this.menuScreenEdgeInset = 8,
  });

  /// Icon color override.
  ///
  /// When `null` (the default), the icon inherits its color from the
  /// ambient [IconButtonTheme] / [AppBarTheme.iconTheme]. Pass an explicit
  /// color only if the button sits on an AppBar background where the
  /// inherited color would have insufficient contrast.
  final Color? iconColor;

  /// Vertical / horizontal drop offset applied to the dropdown menu.
  ///
  /// Defaults to `Offset(0, 8)` — an 8px gap below the button. Horizontal
  /// values here are clamped by Flutter's menu layout if the menu would
  /// otherwise overflow the viewport, so use [menuScreenEdgeInset] for a
  /// reliable trailing-edge buffer.
  final Offset menuAlignmentOffset;

  /// Empty space reserved between the dropdown menu and the trailing
  /// viewport edge (and below the menu, to give the shadow room to
  /// render).
  ///
  /// The button itself stays in place; this inset is applied *inside* the
  /// menu overlay as trailing and bottom padding around the visible menu
  /// surface.
  ///
  /// Defaults to 8. Set to 0 to disable.
  final double menuScreenEdgeInset;

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
          return Icons.brightness_auto;
      }
    }

    final inset = menuScreenEdgeInset.clamp(0, double.infinity).toDouble();

    return MenuAnchor(
      alignmentOffset: menuAlignmentOffset,
      style: MenuStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all(const RoundedRectangleBorder()),
      ),
      menuChildren: [
        Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final mode = AdaptiveTheme.of(context).mode;
            return Padding(
              padding: EdgeInsetsDirectional.only(end: inset, bottom: inset),
              child: Material(
                color: theme.colorScheme.surfaceContainer,
                surfaceTintColor: theme.colorScheme.surfaceTint,
                shadowColor: theme.colorScheme.shadow,
                elevation: 3,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MenuItemButton(
                        onPressed: AdaptiveTheme.of(context).setLight,
                        leadingIcon: const Icon(Icons.light_mode_outlined),
                        trailingIcon: mode == AdaptiveThemeMode.light
                            ? const Icon(Icons.check)
                            : null,
                        child: const Text('Light'),
                      ),
                      MenuItemButton(
                        onPressed: AdaptiveTheme.of(context).setDark,
                        leadingIcon: const Icon(Icons.dark_mode_outlined),
                        trailingIcon: mode == AdaptiveThemeMode.dark
                            ? const Icon(Icons.check)
                            : null,
                        child: const Text('Dark'),
                      ),
                      MenuItemButton(
                        onPressed: AdaptiveTheme.of(context).setSystem,
                        leadingIcon: const Icon(Icons.brightness_auto),
                        trailingIcon: mode.isSystem
                            ? const Icon(Icons.check)
                            : null,
                        child: const Text('System'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return IconButton(
              icon: Icon(getIcon(), color: iconColor),
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
    );
  }
}

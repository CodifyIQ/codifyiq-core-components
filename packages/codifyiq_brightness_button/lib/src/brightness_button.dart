import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:codifyiq_brightness_button/src/brightness_menu_items.dart';
import 'package:material_ui/material_ui.dart';

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
  ///
  /// [tooltip] labels the button; [lightLabel], [darkLabel], and
  /// [systemLabel] label its menu items.
  const BrightnessButton({
    super.key,
    this.iconColor,
    this.menuAlignmentOffset = const Offset(0, 8),
    this.menuScreenEdgeInset = 8,
    this.tooltip = 'Switch Brightness Theme',
    this.lightLabel = 'Light',
    this.darkLabel = 'Dark',
    this.systemLabel = 'System',
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

  /// Tooltip of the button.
  final String tooltip;

  /// Label of the Light item.
  final String lightLabel;

  /// Label of the Dark item.
  final String darkLabel;

  /// Label of the System item.
  final String systemLabel;

  @override
  Widget build(BuildContext context) {
    final adaptiveTheme = AdaptiveTheme.of(context);

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
                    children: brightnessMenuItems(
                      context,
                      lightLabel: lightLabel,
                      darkLabel: darkLabel,
                      systemLabel: systemLabel,
                    ),
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
              icon: Icon(
                brightnessModeIcon(adaptiveTheme.mode),
                color: iconColor,
              ),
              tooltip: tooltip,
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

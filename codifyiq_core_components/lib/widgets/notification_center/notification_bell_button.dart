import 'package:flutter/material.dart';

import 'notification_center_controller.dart';
import 'notification_center_page.dart';
import 'notification_center_panel.dart';

/// App-bar bell button that surfaces a notification center.
///
/// Shows a Material 3 [Badge] with the controller's `unreadCount` whenever
/// there are unseen items. Tapping the bell:
///
/// - On viewports wider than [mobileBreakpoint] (default 600px), opens an
///   anchored dropdown menu hosting a [NotificationCenterPanel].
/// - On narrower viewports, pushes a full-screen [NotificationCenterPage]
///   with a standard back button.
///
/// While the panel/page is mounted, the controller is marked as observed
/// (see [NotificationCenterController.beginObserving]) so the badge stays
/// at zero for any items that arrive or change while the user is looking
/// at them.
///
/// The controller is resolved in this order:
/// 1. The [controller] passed to the constructor, if non-null.
/// 2. The nearest ancestor [NotificationCenterScope].
class NotificationBellButton extends StatefulWidget {
  /// Creates a [NotificationBellButton].
  const NotificationBellButton({
    super.key,
    this.controller,
    this.tooltip = 'Notifications',
    this.icon = Icons.notifications_outlined,
    this.iconColor,
    this.panelWidth = 360,
    this.panelMaxHeight = 480,
    this.panelAlignmentOffset = const Offset(0, 8),
    this.panelScreenEdgeInset = 8,
    this.mobileBreakpoint = 600,
    this.useRootNavigator = true,
    this.emptyPlaceholder,
  });

  /// Controller to read from. When `null`, the widget looks up an ambient
  /// [NotificationCenterScope] via [NotificationCenterScope.of].
  final NotificationCenterController? controller;

  /// Tooltip shown on hover / long-press.
  final String tooltip;

  /// Icon displayed on the bell button.
  final IconData icon;

  /// Icon color override.
  ///
  /// When `null` (the default), the icon inherits its color from the
  /// ambient [IconButtonTheme] / [AppBarTheme.iconTheme]. Pass an explicit
  /// color (e.g. `Theme.of(context).colorScheme.inversePrimary`) only if
  /// the bell sits on a non-default AppBar background where the inherited
  /// color would have insufficient contrast.
  final Color? iconColor;

  /// Width of the dropdown panel (wide layout only).
  final double panelWidth;

  /// Maximum height of the dropdown panel before its content scrolls
  /// (wide layout only).
  final double panelMaxHeight;

  /// Offset applied to the dropdown panel relative to its anchored position
  /// (wide layout only).
  ///
  /// Defaults to `Offset(0, 8)` — an 8px vertical gap below the bell.
  /// Horizontal adjustments via this offset are clamped by Flutter's menu
  /// layout when the panel would otherwise overflow the viewport; use
  /// [panelScreenEdgeInset] for a reliable right-edge buffer.
  final Offset panelAlignmentOffset;

  /// Empty space reserved between the dropdown panel and the trailing
  /// viewport edge (wide layout only).
  ///
  /// The bell itself stays in place; this inset is applied *inside* the
  /// menu overlay as trailing-side padding around the visible panel
  /// surface. The MenuAnchor's invisible container still extends to the
  /// screen edge, but the panel's rounded surface, elevation, and shadow
  /// stop short of it by this many logical pixels.
  ///
  /// Defaults to 8. Set to 0 to disable.
  final double panelScreenEdgeInset;

  /// Viewport width at or below which the bell opens a full-screen
  /// [NotificationCenterPage] instead of an anchored dropdown.
  ///
  /// Defaults to 600px, matching common phone-vs-tablet breakpoints.
  final double mobileBreakpoint;

  /// Whether the full-screen page should be pushed onto the root navigator.
  ///
  /// Defaults to `true`. This avoids stacking the page's [AppBar] beneath a
  /// surrounding shell's [AppBar] (e.g. a GoRouter `ShellRoute`). Set to
  /// `false` only when you specifically want the page to push within a
  /// nested navigator.
  final bool useRootNavigator;

  /// Widget shown inside the panel/page when there are no items.
  final Widget? emptyPlaceholder;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final MenuController _menu = MenuController();

  bool _isNarrow(BuildContext context) {
    return MediaQuery.sizeOf(context).width <= widget.mobileBreakpoint;
  }

  void _openFullScreen(
    BuildContext context,
    NotificationCenterController controller,
  ) {
    Navigator.of(context, rootNavigator: widget.useRootNavigator).push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterPage(
          controller: controller,
          emptyPlaceholder: widget.emptyPlaceholder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        widget.controller ?? NotificationCenterScope.of(context, listen: false);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context, controller),
    );
  }

  Widget _build(BuildContext context, NotificationCenterController controller) {
    final theme = Theme.of(context);
    final unread = controller.unreadCount;
    final bellIcon = Icon(widget.icon, color: widget.iconColor);
    final badged = unread > 0
        ? Badge.count(count: unread, child: bellIcon)
        : bellIcon;

    if (_isNarrow(context)) {
      return IconButton(
        tooltip: widget.tooltip,
        icon: badged,
        onPressed: () => _openFullScreen(context, controller),
      );
    }

    final inset = widget.panelScreenEdgeInset
        .clamp(0, double.infinity)
        .toDouble();
    final totalMenuWidth = widget.panelWidth + inset;
    final totalMenuHeight = widget.panelMaxHeight + inset;
    final panel = Material(
      color: theme.colorScheme.surfaceContainer,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      shadowColor: theme.colorScheme.shadow,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widget.panelWidth,
        child: NotificationCenterPanel(
          controller: controller,
          maxHeight: widget.panelMaxHeight,
          emptyPlaceholder: widget.emptyPlaceholder,
        ),
      ),
    );

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: widget.panelAlignmentOffset,
      style: MenuStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all(const RoundedRectangleBorder()),
        maximumSize: WidgetStateProperty.all(
          Size(totalMenuWidth, totalMenuHeight),
        ),
        minimumSize: WidgetStateProperty.all(Size(totalMenuWidth, 0)),
      ),
      menuChildren: [
        Padding(
          padding: EdgeInsetsDirectional.only(end: inset, bottom: inset),
          child: panel,
        ),
      ],
      builder: (context, menuController, _) {
        return IconButton(
          tooltip: widget.tooltip,
          icon: badged,
          onPressed: () {
            if (menuController.isOpen) {
              menuController.close();
            } else {
              menuController.open();
            }
          },
        );
      },
    );
  }
}

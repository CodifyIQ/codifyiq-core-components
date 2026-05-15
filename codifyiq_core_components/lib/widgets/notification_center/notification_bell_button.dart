import 'package:flutter/material.dart';

import 'notification_center_controller.dart';
import 'notification_center_page.dart';
import 'notification_center_panel.dart';

/// App-bar bell button that surfaces a notification center.
///
/// Shows a Material 3 [Badge] colored by the controller's aggregate status,
/// with the bell icon swapping to [activeIcon] whenever items are tracked
/// so state is conveyed by shape as well as color (WCAG 1.4.1).
///
/// **Status priority** (highest to lowest): error → running → success →
/// none. A single unseen failure beats any in-flight work, so a regression
/// is never hidden behind an in-progress indicator.
///
/// **Badge label rules**:
///
/// - **running** → amber dot, never a count. Running is ambient state
///   ("something's happening"); the running count isn't actionable.
/// - **success** → green count of unseen successes. Always homogeneous
///   by construction: success only wins when no running items and no
///   unseen errors exist.
/// - **error** → red count of unseen failures when no running items
///   exist; a red `!` glyph when an unseen failure coexists with
///   running work (a count would mask the in-flight items).
///
/// **Quiet semantics**: success and error are notification events, gated
/// by `seen` — opening the panel marks items seen and the bell quiets if
/// nothing else is running. Running is current state, not gated by
/// `seen`, so the bell stays lit while work is in flight even after the
/// user has peeked.
///
/// Tapping the bell:
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
    this.activeIcon = Icons.notifications,
    this.iconColor,
    this.runningColor,
    this.successColor,
    this.errorColor,
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

  /// Icon displayed on the bell button when there are no tracked items.
  final IconData icon;

  /// Icon displayed on the bell button when at least one item is tracked.
  ///
  /// Swapping to a filled bell variant gives shape differentiation in
  /// addition to the badge color, which helps colorblind users and meets
  /// WCAG 1.4.1 (information not conveyed by color alone).
  final IconData activeIcon;

  /// Color used for the badge when items are running and none have failed.
  ///
  /// Defaults to a Material amber (`Colors.amber.shade700`) so the badge
  /// reads as a stoplight "in progress" tone. MD3 has no built-in
  /// "warning" role, and `colorScheme.tertiary` lands on a green/teal in
  /// many seeded palettes which would be easily mistaken for "complete" —
  /// hence the explicit amber. Pass any color to override.
  final Color? runningColor;

  /// Color used for the badge when every tracked item completed successfully.
  ///
  /// Defaults to a Material green (`Colors.green.shade800`) chosen so the
  /// default white-on-green badge text clears WCAG AA contrast (~5:1)
  /// while still reading as "done" on both light and dark surfaces. MD3
  /// has no built-in "success" role and `colorScheme.primary` is
  /// typically a brand color (blue/purple), which doesn't read as
  /// "done." Pass any color to override; the badge text color is
  /// auto-selected for contrast.
  final Color? successColor;

  /// Color used for the badge when at least one item has failed.
  ///
  /// Defaults to `theme.colorScheme.error`.
  final Color? errorColor;

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
    final badged = _buildBadgedBell(context, controller, theme);

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

  Widget _buildBadgedBell(
    BuildContext context,
    NotificationCenterController controller,
    ThemeData theme,
  ) {
    final state = controller.bellState;
    final status = state.status;
    final iconData = status == NotificationBellAggregateStatus.none
        ? widget.icon
        : widget.activeIcon;
    final bell = Icon(iconData, color: widget.iconColor);

    if (status == NotificationBellAggregateStatus.none) return bell;

    final bg = switch (status) {
      NotificationBellAggregateStatus.error =>
        widget.errorColor ?? theme.colorScheme.error,
      NotificationBellAggregateStatus.running =>
        widget.runningColor ?? Colors.amber.shade700,
      NotificationBellAggregateStatus.success =>
        widget.successColor ?? Colors.green.shade800,
      NotificationBellAggregateStatus.none => theme.colorScheme.surface,
    };
    // Pick fg based on bg luminance so consumer-supplied colors stay
    // legible. Pairing `errorColor` with `scheme.onError` (etc.) breaks
    // the moment a caller overrides the bg.
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    // Running is ambient state — show just a dot, never a count. Counts
    // only matter for completion events the user might act on.
    final count = status == NotificationBellAggregateStatus.running
        ? null
        : state.count;
    final label = count != null ? Text('$count') : _glyphFor(status, fg);

    return Badge(backgroundColor: bg, textColor: fg, label: label, child: bell);
  }

  Widget? _glyphFor(NotificationBellAggregateStatus status, Color fg) {
    switch (status) {
      case NotificationBellAggregateStatus.error:
        // Reached when an unseen error coexists with running work — the
        // count would be misleading because running items are also
        // contributing to the bell.
        return Icon(Icons.priority_high, size: 10, color: fg);
      case NotificationBellAggregateStatus.success:
        // Success only wins when there are no running items and no
        // unseen errors, so contributing items are homogeneous and the
        // count branch is always taken upstream. If we get here, the
        // invariant in NotificationCenterController.bellState has drifted.
        assert(
          false,
          'success status reached _glyphFor; bellState invariant broken',
        );
        return null;
      case NotificationBellAggregateStatus.running:
      case NotificationBellAggregateStatus.none:
        return null;
    }
  }
}

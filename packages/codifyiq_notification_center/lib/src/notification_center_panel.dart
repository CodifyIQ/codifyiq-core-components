import 'package:flutter/material.dart';

import 'notification_center_controller.dart';
import 'notification_item.dart';

/// Dropdown panel listing the items in a [NotificationCenterController].
///
/// Renders three sections in order — **In progress**, **Failed**,
/// **Completed** — each preceded by a small header label. A running item
/// shows a single progress indicator: a leading spinner when its progress
/// is indeterminate, or just a linear progress bar (no leading glyph) when
/// it reports a determinate value. Finished items show a status icon
/// and an optional trailing action. Completed items can be dismissed with
/// a trailing close button.
///
/// Normally constructed implicitly by [NotificationBellButton]; expose
/// directly if you need to embed the list elsewhere (e.g. a side panel).
///
/// While mounted, the panel registers as an observer on its controller via
/// [NotificationCenterController.beginObserving] / [endObserving], so the
/// bell badge stays at zero for items that arrive or change while the user
/// is looking at the panel.
class NotificationCenterPanel extends StatefulWidget {
  /// Creates a [NotificationCenterPanel].
  const NotificationCenterPanel({
    super.key,
    required this.controller,
    this.maxHeight = 480,
    this.emptyPlaceholder,
    this.showHeader = true,
  });

  /// Backing controller.
  final NotificationCenterController controller;

  /// Maximum panel height before its content scrolls.
  ///
  /// Pass `double.infinity` (or any large value) to let the panel expand to
  /// fill its parent — useful when embedding it inside a full-screen page.
  final double maxHeight;

  /// Widget shown when the controller is empty. Defaults to a muted
  /// "No notifications" message.
  final Widget? emptyPlaceholder;

  /// Whether to render the in-panel "Notifications" title row with its
  /// inline "Clear completed" action.
  ///
  /// Defaults to `true`. Set to `false` when the panel is embedded inside a
  /// page that already provides its own [AppBar] title (e.g.
  /// [NotificationCenterPage]).
  final bool showHeader;

  @override
  State<NotificationCenterPanel> createState() =>
      _NotificationCenterPanelState();
}

class _NotificationCenterPanelState extends State<NotificationCenterPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.beginObserving();
  }

  @override
  void didUpdateWidget(NotificationCenterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.endObserving();
      widget.controller.beginObserving();
    }
  }

  @override
  void dispose() {
    widget.controller.endObserving();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller.structureListenable,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final running = controller.running;
    final failed = controller.failed;
    final succeeded = controller.succeeded;
    final hasAnyCompleted = failed.isNotEmpty || succeeded.isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader)
            _Header(
              title: 'Notifications',
              trailing: hasAnyCompleted
                  ? TextButton(
                      onPressed: controller.clearCompleted,
                      child: const Text(
                        'Clear completed',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )
                  : null,
            ),
          if (controller.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(
                child:
                    widget.emptyPlaceholder ??
                    Text(
                      'No notifications',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (running.isNotEmpty)
                      _Section(
                        label: 'In progress',
                        items: running,
                        controller: controller,
                      ),
                    if (failed.isNotEmpty)
                      _Section(
                        label: 'Failed',
                        items: failed,
                        controller: controller,
                      ),
                    if (succeeded.isNotEmpty)
                      _Section(
                        label: 'Completed',
                        items: succeeded,
                        controller: controller,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (trailing != null) Flexible(child: trailing!),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.items,
    required this.controller,
  });

  final String label;
  final List<NotificationItem> items;
  final NotificationCenterController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  _NotificationRow(
                    key: ValueKey(items[i].id),
                    controller: controller,
                    itemId: items[i].id,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    super.key,
    required this.controller,
    required this.itemId,
  });

  final NotificationCenterController controller;
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final listenable = controller.itemListenable(itemId);
    if (listenable == null) return const SizedBox.shrink();
    return ValueListenableBuilder<NotificationItem>(
      valueListenable: listenable,
      builder: (context, item, _) =>
          _RowContent(item: item, onDismiss: () => controller.dismiss(itemId)),
    );
  }
}

class _RowContent extends StatelessWidget {
  const _RowContent({required this.item, required this.onDismiss});

  final NotificationItem item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leading = _leadingFor(theme);
    final trailing = _trailingFor(context);

    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: leading,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  // Only a determinate task earns the linear bar — it shows
                  // *how far along* the work is. An indeterminate task
                  // (unknown duration, progress == null) is signalled solely
                  // by the leading spinner, so we never stack two indicators
                  // that say the same value-less "something's happening."
                  if (item.isRunning && item.progress != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              Padding(padding: const EdgeInsets.only(left: 8), child: trailing),
          ],
        ),
      ),
    );
  }

  Widget? _leadingFor(ThemeData theme) {
    switch (item.status) {
      case NotificationItemStatus.running:
        // Exactly one progress indicator per running row (MD3):
        //   • Indeterminate (progress == null) — the spinner *is* the
        //     indicator. At 20px the arc isn't legible as a value, but it
        //     reads clearly as "working," which is all an unknown-duration
        //     task can honestly say.
        //   • Determinate (progress != null) — the legible value lives in
        //     the LinearProgressIndicator below the text, so the leading
        //     slot is dropped entirely; the bar alone carries the row.
        if (item.progress == null) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          );
        }
        return null;
      case NotificationItemStatus.success:
        return Icon(
          Icons.check_circle,
          size: 22,
          color: theme.colorScheme.primary,
        );
      case NotificationItemStatus.error:
        return Icon(Icons.error, size: 22, color: theme.colorScheme.error);
    }
  }

  Widget? _trailingFor(BuildContext context) {
    final children = <Widget>[];
    if (item.action != null) {
      children.add(
        TextButton(
          onPressed: item.action!.onPressed,
          child: Text(item.action!.label),
        ),
      );
    }
    if (item.isCompleted) {
      children.add(
        IconButton(
          tooltip: 'Dismiss',
          icon: const Icon(Icons.close, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: onDismiss,
        ),
      );
    }
    if (children.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

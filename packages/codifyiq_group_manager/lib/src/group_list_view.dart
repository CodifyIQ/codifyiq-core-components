import 'package:flutter/material.dart';

import 'group.dart';
import 'group_avatar.dart';
import 'group_editor_dialog.dart';
import 'group_manager_controller.dart';

/// A scrollable catalog of the groups in a [GroupManagerController], with
/// built-in edit and delete affordances.
///
/// The list is controller-driven: it rebuilds when the catalog changes, and
/// edits and deletes apply to the controller directly. Supply an explicit
/// [controller], or omit it to resolve the nearest [GroupManagerScope].
///
/// The built-in editor dialog and delete confirmation always run; the
/// controller is updated optimistically, then [onEdit] / [onDelete] fire with
/// the resulting group so you can persist the change to a backend (rolling back
/// via the controller on failure). Provide [onTap] to make rows selectable —
/// e.g. to reveal a group's members elsewhere in your UI.
///
/// Groups whose ids are in [lockedIds] are protected: their row offers no
/// Delete action, so a permanent group (e.g. "Administrators") can't be removed
/// from the catalog. Editing such a group is still allowed — changing its name
/// or color doesn't break the invariant that the group keeps existing.
class GroupListView extends StatelessWidget {
  /// Creates a [GroupListView].
  const GroupListView({
    super.key,
    this.controller,
    this.query = '',
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.lockedIds = const <String>{},
    this.showActions = true,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.shrinkWrap = false,
    this.physics,
    this.emptyState,
    this.footer,
  });

  /// The controller to render. When `null`, the nearest [GroupManagerScope] is
  /// used.
  final GroupManagerController? controller;

  /// Case-insensitive filter applied to each group's name and description. When
  /// empty (the default), every group is shown. Drive this from a search field
  /// — [GroupManagerView] does so out of the box.
  final String query;

  /// Called when a row is tapped. When `null`, rows are not tappable.
  final ValueChanged<Group>? onTap;

  /// Called after a row is edited through the built-in [GroupEditorDialog] and
  /// the change is applied via [GroupManagerController.updateGroup], with the
  /// updated group. Use it to persist the edit to a backend.
  final ValueChanged<Group>? onEdit;

  /// Called after a group is deleted through the built-in confirmation dialog
  /// and removed via [GroupManagerController.removeGroup] (cascade-unassigning
  /// it from every member), with the deleted group. Use it to persist the
  /// deletion to a backend.
  final ValueChanged<Group>? onDelete;

  /// Ids of groups that are protected from deletion. Their row carries a lock
  /// badge (tooltip: "Locked — can't be deleted") and its menu omits the Delete
  /// action; they remain editable.
  ///
  /// This protection is presentational: it withholds the affordance, but the
  /// controller is not guarded — [GroupManagerController.removeGroup] still
  /// deletes a locked group if called directly, and a custom row menu built
  /// with `showActions: false` enforces nothing. Mirrors how `lockedIds` works
  /// in [GroupAssignmentField] and [GroupPicker], where it shapes the UI rather
  /// than the underlying state.
  final Set<String> lockedIds;

  /// Whether to show the per-row edit/delete menu.
  final bool showActions;

  /// Padding around the list.
  final EdgeInsetsGeometry padding;

  /// Whether the list should size itself to its content.
  final bool shrinkWrap;

  /// Scroll physics forwarded to the underlying [ListView].
  final ScrollPhysics? physics;

  /// Widget shown when the catalog is empty. Defaults to a centered hint.
  final Widget? emptyState;

  /// Optional widget rendered as the final scrolling item, after the last
  /// group — e.g. a help or policy note. Scrolls with the list rather than
  /// pinning to the viewport.
  ///
  /// Shown only when groups are listed. It is deliberately suppressed in the
  /// empty and no-matches states, which already own the viewport with their own
  /// messaging — appending a trailing note beneath "No groups match …" would
  /// read as orphaned. Put copy that must always be visible outside the list.
  final Widget? footer;

  GroupManagerController _resolve(BuildContext context) =>
      controller ?? GroupManagerScope.of(context, listen: false);

  List<Group> _applyQuery(List<Group> groups) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return groups;
    return groups
        .where(
          (g) =>
              g.name.toLowerCase().contains(q) ||
              (g.description?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  Future<void> _handleEdit(BuildContext context, Group group) async {
    final ctrl = _resolve(context);
    final edited = await GroupEditorDialog.show(context, initial: group);
    if (edited == null) return;
    ctrl.updateGroup(edited);
    onEdit?.call(edited);
  }

  Future<void> _handleDelete(BuildContext context, Group group) async {
    final ctrl = _resolve(context);
    final confirmed = await showDialog<bool>(
      context: context,
      // Use the dialog's own context to pop — popping via the outer context
      // resolves to a nested navigator and dismisses the page route instead.
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${group.name}"?'),
        content: const Text(
          'This removes the group and unassigns it from every member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    ctrl.removeGroup(group.id);
    onDelete?.call(group);
  }

  @override
  Widget build(BuildContext context) {
    // listen: false — the ListenableBuilder below already drives rebuilds, so
    // an inherited dependency here would just double the rebuild path.
    final ctrl = controller ?? GroupManagerScope.of(context, listen: false);
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        if (ctrl.isEmpty) {
          return emptyState ?? const _EmptyCatalog();
        }
        final groups = _applyQuery(ctrl.groups);
        if (groups.isEmpty) {
          return _NoMatches(query: query.trim());
        }
        final hasFooter = footer != null;
        return ListView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: groups.length + (hasFooter ? 1 : 0),
          itemBuilder: (context, index) {
            // The footer trails the rows as the final scrolling item.
            if (hasFooter && index == groups.length) return footer;
            final group = groups[index];
            final locked = lockedIds.contains(group.id);
            return ListTile(
              leading: GroupAvatar(group: group),
              title: Text(group.name),
              subtitle: group.description == null
                  ? null
                  : Text(
                      group.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: onTap == null ? null : () => onTap!(group),
              trailing: showActions
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A lock badge explains the missing Delete action so its
                        // absence doesn't read as a bug. The metaphor matches
                        // the locked tooltip used by GroupAssignmentField and
                        // GroupPicker; the wording parallels it for the catalog's
                        // delete (rather than remove) action.
                        if (locked)
                          Tooltip(
                            message: "Locked — can't be deleted",
                            child: Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        _RowMenu(
                          onEdit: () => _handleEdit(context, group),
                          // A locked group is protected from deletion: withhold
                          // the Delete action entirely rather than disabling it.
                          onDelete: locked
                              ? null
                              : () => _handleDelete(context, group),
                        ),
                      ],
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.onEdit, this.onDelete});

  final VoidCallback onEdit;

  /// Deletes the group, or `null` for a locked group, which omits the action.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) => IconButton(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Group actions',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      // Per MD3, error coloring is reserved for the actual irreversible action
      // (the Delete button in the confirmation dialog), not the menu trigger
      // that merely opens that dialog.
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          child: const Text('Edit'),
        ),
        if (onDelete != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
            child: const Text('Delete'),
          ),
      ],
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No groups yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Create a group to start assigning members.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No groups match "$query"',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

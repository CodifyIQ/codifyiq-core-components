import 'package:flutter/material.dart';

import 'group.dart';
import 'group_editor_dialog.dart';
import 'group_list_view.dart';
import 'group_manager_controller.dart';

/// A complete, drop-in catalog-management surface.
///
/// Combines a "New group" action, a search field, and a [GroupListView], wired
/// to a [GroupManagerController] for the full create / edit / delete lifecycle.
/// Designed to be dropped straight into a [Scaffold] body. Supply an explicit
/// [controller] or omit it to resolve the nearest [GroupManagerScope].
///
/// The search field filters the catalog by name and description; it appears
/// once the catalog is non-empty (set [searchable] to `false` to hide it). For
/// finer control, compose [GroupListView] and [GroupEditorDialog] directly
/// instead.
///
/// ## Wiring to a repository
///
/// By default, create / edit / delete apply directly to the controller —
/// perfect for local-only state. To persist to a backend, supply [onCreate],
/// [onEdit], and [onDelete]: the built-in create / edit dialogs and delete
/// confirmation still run and the controller is updated optimistically, then
/// the callback fires with the resulting group so you can persist it and roll
/// back via the controller on failure. Because the controller's listeners only
/// drive UI rebuilds, mutating it never re-triggers these callbacks, so there
/// is no feedback loop.
///
/// ```dart
/// GroupManagerView(
///   controller: controller,
///   // The group is already added locally; persist it and undo on failure.
///   onCreate: (group) async {
///     try {
///       await repository.create(group);
///     } catch (e) {
///       controller.removeGroup(group.id); // roll back the optimistic add
///       // ...and surface the error to the user
///     }
///   },
///   // The group is already removed locally; persist the deletion.
///   onDelete: (group) => repository.delete(group.id),
/// );
/// ```
class GroupManagerView extends StatefulWidget {
  /// Creates a [GroupManagerView].
  const GroupManagerView({
    super.key,
    this.controller,
    this.onTap,
    this.onCreate,
    this.onEdit,
    this.onDelete,
    this.lockedIds = const <String>{},
    this.searchable = true,
    this.padding = const EdgeInsets.all(16),
    this.maxContentWidth = 840,
    this.createButtonLabel = 'New group',
    this.footer,
  });

  /// The controller to manage. When `null`, the nearest [GroupManagerScope] is
  /// used.
  final GroupManagerController? controller;

  /// Called when a group row is tapped — e.g. to drill into its members.
  final ValueChanged<Group>? onTap;

  /// Called after a new group is created through the built-in dialog and added
  /// via [GroupManagerController.addGroup], with the created group. Use it to
  /// persist the creation to a backend.
  final ValueChanged<Group>? onCreate;

  /// Called after a row is edited and applied to the controller, forwarded to
  /// [GroupListView.onEdit]. Use it to persist the edit to a backend.
  final ValueChanged<Group>? onEdit;

  /// Called after a group is deleted and removed from the controller, forwarded
  /// to [GroupListView.onDelete]. Use it to persist the deletion to a backend.
  final ValueChanged<Group>? onDelete;

  /// Ids of groups that are protected from deletion, forwarded to
  /// [GroupListView.lockedIds]. Their rows offer no Delete action — use it to
  /// keep a permanent group (e.g. "Administrators") in the catalog. Such groups
  /// remain editable. The protection is presentational only; see
  /// [GroupListView.lockedIds] for the boundary.
  final Set<String> lockedIds;

  /// Whether to show the search field once the catalog has groups.
  final bool searchable;

  /// Padding around the surface.
  final EdgeInsetsGeometry padding;

  /// Maximum content width, in logical pixels.
  ///
  /// Follows M3's large-screen guidance: the content (search bar, list, create
  /// action) fills narrow panes but is capped at this width and centered on
  /// wider ones, so it doesn't stretch to an uncomfortable measure. Defaults to
  /// 840 (the medium/expanded window boundary). Pass `null` to fill the pane
  /// edge-to-edge.
  final double? maxContentWidth;

  /// Label for the create action.
  final String createButtonLabel;

  /// Optional widget rendered as the final scrolling item beneath the last
  /// group, forwarded to [GroupListView.footer] — e.g. a help or policy note.
  /// It scrolls with the catalog and shares its centered, padded measure. Shown
  /// only when groups are listed; see [GroupListView.footer] for the empty and
  /// no-matches behavior.
  final Widget? footer;

  @override
  State<GroupManagerView> createState() => _GroupManagerViewState();
}

class _GroupManagerViewState extends State<GroupManagerView> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  GroupManagerController get _controller =>
      widget.controller ?? GroupManagerScope.of(context, listen: false);

  Future<void> _create() async {
    final created = await GroupEditorDialog.show(context);
    if (created == null) return;
    _controller.addGroup(created);
    widget.onCreate?.call(created);
  }

  void _onQueryChanged(String value) => setState(() => _query = value);

  @override
  Widget build(BuildContext context) {
    // listen: false — the ListenableBuilder below already drives rebuilds.
    final ctrl =
        widget.controller ?? GroupManagerScope.of(context, listen: false);
    final maxWidth = widget.maxContentWidth;
    final content = Padding(
      padding: widget.padding,
      child: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final showSearch = widget.searchable && !ctrl.isEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showSearch)
                Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        controller: _search,
                        hintText: 'Search groups',
                        leading: const Icon(Icons.search),
                        // M3 search has no shadow by default.
                        elevation: const WidgetStatePropertyAll(0),
                        trailing: [
                          if (_query.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _search.clear();
                                _onQueryChanged('');
                              },
                            ),
                        ],
                        onChanged: _onQueryChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Create sits outside the search bar so it reads as its own
                    // action rather than a search affordance. Outlined (MD3
                    // medium emphasis) gives it definition against the surface
                    // without competing with the search bar for prominence.
                    IconButton.outlined(
                      icon: const Icon(Icons.add),
                      tooltip: widget.createButtonLabel,
                      onPressed: _create,
                    ),
                  ],
                )
              else
                // No search bar to host the action when the catalog is empty —
                // offer a standalone create button instead.
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(widget.createButtonLabel),
                    onPressed: _create,
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: GroupListView(
                  controller: ctrl,
                  query: showSearch ? _query : '',
                  onTap: widget.onTap,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                  lockedIds: widget.lockedIds,
                  footer: widget.footer,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (maxWidth == null) return content;
    // Cap and center on wide panes; fills narrow ones (the constraint is looser
    // than the available width there, so it's a no-op).
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}

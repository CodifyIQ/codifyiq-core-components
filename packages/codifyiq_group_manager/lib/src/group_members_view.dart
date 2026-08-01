import 'package:flutter/material.dart';

import 'bulk_selection_bar.dart';
import 'group_manager_controller.dart';
import 'member_picker.dart';
import 'principal.dart';
import 'principal_avatar.dart';

/// A complete, drop-in surface for managing one group's membership.
///
/// The group-side mirror of [GroupManagerView]: an "Edit members" action, a
/// search field, and a scrollable member list with per-row and bulk removal,
/// wired to a [GroupManagerController]. Designed to be dropped straight into a
/// [Scaffold] body — typically the destination of [GroupManagerView.onTap], so
/// tapping a group in the catalog drills into its members.
///
/// ```dart
/// GroupManagerView(
///   controller: controller,
///   onTap: (group) => Navigator.of(context).push(
///     MaterialPageRoute(
///       builder: (_) => Scaffold(
///         appBar: AppBar(title: Text(group.name)),
///         body: GroupMembersView(
///           groupId: group.id,
///           roster: allUsers,
///           controller: controller,
///         ),
///       ),
///     ),
///   ),
/// );
/// ```
///
/// The [roster] is caller-owned. The controller stores principal ids, not a
/// roster, so it cannot enumerate principals who belong to no group — pass
/// everyone who *could* be a member here, not just those who already are. A
/// current member missing from [roster] cannot be rendered, so it is listed as
/// an unknown principal rather than silently dropped; keep [roster] a superset
/// of the group's membership.
///
/// The "Edit members" action opens a [MemberPicker] seeded with the current
/// membership, so one pass can both add and remove — the same framing as
/// [GroupAssignmentField]'s "Edit" affordance. Per-row and bulk removal are
/// quick paths for the common case, and both confirm first.
///
/// Principals whose ids are in [lockedMemberIds] are permanent members: their
/// row carries a lock badge, offers no Remove action, and cannot be checked for
/// a bulk removal; they are also checked-and-disabled in the picker. Like every
/// other `locked*` set in this package the protection is presentational — it
/// withholds affordances, but [GroupManagerController.setMembers] still drops a
/// locked member if called directly.
///
/// ## Wiring to a repository
///
/// By default, membership changes apply directly to the controller — perfect
/// for local-only state. To persist to a backend, supply [onMembersAdded] and
/// [onMembersRemoved]: the controller is updated optimistically, then the
/// callback fires with the affected principal ids so you can persist and roll
/// back via the controller on failure. Because the controller's listeners only
/// drive UI rebuilds, mutating it never re-triggers these callbacks, so there
/// is no feedback loop.
class GroupMembersView extends StatefulWidget {
  /// Creates a [GroupMembersView].
  const GroupMembersView({
    super.key,
    required this.groupId,
    required this.roster,
    this.controller,
    this.onMembersAdded,
    this.onMembersRemoved,
    this.lockedMemberIds = const <String>{},
    this.searchable = true,
    this.padding = const EdgeInsets.all(16),
    this.maxContentWidth = 840,
    this.editButtonLabel = 'Edit members',
    this.emptyState,
    this.footer,
    this.avatarHeaders,
    this.avatarImageProviderBuilder,
  });

  /// Id of the group whose membership this manages.
  ///
  /// Resolved against the catalog on every rebuild rather than taking a [Group]
  /// value, so a rename elsewhere is reflected here immediately. If the group
  /// is deleted while this view is open, it renders a "no longer exists" state
  /// instead of operating on a group that is gone.
  final String groupId;

  /// Every principal that may be a member. See the class doc — this is
  /// caller-owned, because the controller has no roster of its own.
  final List<Principal> roster;

  /// The controller to manage. When `null`, the nearest [GroupManagerScope] is
  /// used.
  final GroupManagerController? controller;

  /// Called after principals are added to the group and applied to the
  /// controller, with the ids that were newly added (never the ones that were
  /// already members). Use it to persist the addition to a backend.
  final ValueChanged<Set<String>>? onMembersAdded;

  /// Called after principals are removed from the group and applied to the
  /// controller, with the ids that were actually removed. Use it to persist the
  /// removal to a backend.
  final ValueChanged<Set<String>>? onMembersRemoved;

  /// Ids of members that cannot be removed through this surface. Their row
  /// carries a lock badge (tooltip: "Locked — can't be removed"), offers no
  /// Remove action, and is not selectable for bulk removal.
  final Set<String> lockedMemberIds;

  /// Whether to show the search field once the group has members.
  final bool searchable;

  /// Padding around the surface.
  final EdgeInsetsGeometry padding;

  /// Maximum content width, in logical pixels. Matches
  /// [GroupManagerView.maxContentWidth]; pass `null` to fill the pane.
  final double? maxContentWidth;

  /// Label for the action that opens the member picker. The picker both adds
  /// and removes, so this defaults to "Edit members" rather than "Add".
  final String editButtonLabel;

  /// Widget shown when the group has no members. Defaults to a centered hint.
  final Widget? emptyState;

  /// Optional widget rendered as the final scrolling item, beneath the last
  /// member — e.g. a help or policy note. Shown only when members are listed;
  /// suppressed in the empty and no-matches states, which already own the
  /// viewport with their own messaging. Mirrors [GroupListView.footer].
  final Widget? footer;

  /// HTTP headers forwarded to every member avatar's image provider — in the
  /// rows, the chips, and the "Edit members" picker. Pass an `Authorization`
  /// token here when the photo endpoint is protected; without it a protected
  /// photo fails to load and each avatar falls back to initials.
  ///
  /// See [PrincipalAvatar.headers].
  final Map<String, String>? avatarHeaders;

  /// Builds the [ImageProvider] for every member avatar's photo — in the rows,
  /// the chips, and the "Edit members" picker. Supply the same builder the rest
  /// of the app uses so a member's photo is served from one shared cache rather
  /// than refetched per screen.
  ///
  /// See [PrincipalAvatar.imageProviderBuilder].
  final PrincipalAvatarImageProviderBuilder? avatarImageProviderBuilder;

  @override
  State<GroupMembersView> createState() => _GroupMembersViewState();
}

class _GroupMembersViewState extends State<GroupMembersView> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// Ids checked for bulk removal. Cleared once applied.
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  GroupManagerController get _controller =>
      widget.controller ?? GroupManagerScope.of(context, listen: false);

  /// The group's members, in roster order, plus a placeholder for any member id
  /// the roster doesn't cover — surfacing the gap rather than hiding the
  /// assignment. Filtered by the current search query.
  List<Principal> _members(Set<String> memberIds) {
    final known = {for (final p in widget.roster) p.id};
    final resolved = <Principal>[
      for (final principal in widget.roster)
        if (memberIds.contains(principal.id)) principal,
      for (final id in memberIds)
        if (!known.contains(id))
          Principal(id: id, name: id, description: 'Not in the roster'),
    ];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return resolved;
    return [
      for (final principal in resolved)
        if (principal.name.toLowerCase().contains(q) ||
            (principal.description?.toLowerCase().contains(q) ?? false))
          principal,
    ];
  }

  Future<void> _editMembers(BuildContext context, String groupName) async {
    final current = _controller.membersOf(widget.groupId);
    final result = await MemberPicker.show(
      context,
      roster: widget.roster,
      initiallySelected: current,
      lockedIds: widget.lockedMemberIds,
      title: 'Members of "$groupName"',
      avatarHeaders: widget.avatarHeaders,
      avatarImageProviderBuilder: widget.avatarImageProviderBuilder,
    );
    if (result == null || !context.mounted) return;

    final added = result.difference(current);
    final removed = current.difference(result);
    _controller.setMembers(widget.groupId, result);
    setState(() => _selected.removeAll(removed));
    if (added.isNotEmpty) widget.onMembersAdded?.call(added);
    if (removed.isNotEmpty) widget.onMembersRemoved?.call(removed);
  }

  Future<void> _remove(
    BuildContext context,
    Set<String> ids,
    String groupName,
  ) async {
    if (ids.isEmpty) return;
    if (!await _confirmRemoval(context, ids.length, groupName)) return;
    if (!context.mounted) return;

    _controller.unassignMany(ids, <String>{widget.groupId});
    setState(() => _selected.removeAll(ids));
    widget.onMembersRemoved?.call(ids);
  }

  Future<bool> _confirmRemoval(
    BuildContext context,
    int count,
    String groupName,
  ) async {
    return await showDialog<bool>(
          context: context,
          // Use the dialog's own context to pop — popping via the outer context
          // resolves to a nested navigator and dismisses the page route instead.
          builder: (dialogContext) => AlertDialog(
            title: Text(
              count == 1
                  ? 'Remove member from "$groupName"?'
                  : 'Remove $count members from "$groupName"?',
            ),
            content: const Text('They keep their other group memberships.'),
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
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Selects every currently-visible, unlocked member, or clears the selection
  /// entirely — "None" always clears everything, even a member checked while a
  /// search filter hid the rest, matching Gmail's "Select: None".
  void _setSelection(List<Principal> visible, {required bool selectAll}) {
    if (selectAll) {
      _selected.addAll(
        visible
            .where((p) => !widget.lockedMemberIds.contains(p.id))
            .map((p) => p.id),
      );
    } else {
      _selected.clear();
    }
  }

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
          final group = ctrl.groupById(widget.groupId);
          if (group == null) return const _DeletedGroup();

          final memberIds = ctrl.membersOf(widget.groupId);
          final members = _members(memberIds);
          final showSearch = widget.searchable && memberIds.isNotEmpty;
          // Locked members are never selectable, so they must not count toward
          // "everything visible is selected" — otherwise the tristate checkbox
          // could never reach its checked state on a list containing one.
          final selectable = [
            for (final member in members)
              if (!widget.lockedMemberIds.contains(member.id)) member,
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                controller: _search,
                query: _query,
                showSearch: showSearch,
                editButtonLabel: widget.editButtonLabel,
                onQueryChanged: (value) => setState(() => _query = value),
                onEdit: () => _editMembers(context, group.name),
              ),
              const SizedBox(height: 12),
              if (memberIds.isNotEmpty)
                BulkSelectionBar(
                  selectedCount: _selected.length,
                  allVisibleSelected:
                      selectable.isNotEmpty &&
                      selectable.every((p) => _selected.contains(p.id)),
                  emptyLabel: 'No members selected',
                  onSelectAll: (choice) => setState(
                    () => _setSelection(
                      selectable,
                      selectAll: choice == BulkSelectAll.all,
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Remove from group',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () =>
                          _remove(context, Set.of(_selected), group.name),
                    ),
                  ],
                ),
              Expanded(
                child: _MemberList(
                  members: members,
                  hasMembers: memberIds.isNotEmpty,
                  query: _query.trim(),
                  selected: _selected,
                  lockedIds: widget.lockedMemberIds,
                  emptyState: widget.emptyState,
                  footer: widget.footer,
                  avatarHeaders: widget.avatarHeaders,
                  avatarImageProviderBuilder: widget.avatarImageProviderBuilder,
                  onSelectionChanged: (id, checked) => setState(() {
                    if (checked) {
                      _selected.add(id);
                    } else {
                      _selected.remove(id);
                    }
                  }),
                  onRemove: (id) => _remove(context, <String>{id}, group.name),
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

/// The search field and "Edit members" action, laid out exactly as
/// [GroupManagerView]'s search-and-create header so the two surfaces read as a
/// pair.
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.query,
    required this.showSearch,
    required this.editButtonLabel,
    required this.onQueryChanged,
    required this.onEdit,
  });

  final TextEditingController controller;
  final String query;
  final bool showSearch;
  final String editButtonLabel;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (!showSearch) {
      // No search bar to host the action when the group is empty — offer a
      // standalone button instead, matching GroupManagerView's empty catalog.
      return Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          icon: const Icon(Icons.person_add_alt),
          label: Text(editButtonLabel),
          onPressed: onEdit,
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: SearchBar(
            controller: controller,
            hintText: 'Search members',
            leading: const Icon(Icons.search),
            // M3 search has no shadow by default.
            elevation: const WidgetStatePropertyAll(0),
            trailing: [
              if (query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    onQueryChanged('');
                  },
                ),
            ],
            onChanged: onQueryChanged,
          ),
        ),
        const SizedBox(width: 8),
        // Outlined (MD3 medium emphasis) gives the action definition against
        // the surface without competing with the search bar for prominence.
        IconButton.outlined(
          icon: const Icon(Icons.person_add_alt),
          tooltip: editButtonLabel,
          onPressed: onEdit,
        ),
      ],
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.hasMembers,
    required this.query,
    required this.selected,
    required this.lockedIds,
    required this.emptyState,
    required this.footer,
    required this.avatarHeaders,
    required this.avatarImageProviderBuilder,
    required this.onSelectionChanged,
    required this.onRemove,
  });

  final List<Principal> members;
  final bool hasMembers;
  final String query;
  final Set<String> selected;
  final Set<String> lockedIds;
  final Widget? emptyState;
  final Widget? footer;
  final Map<String, String>? avatarHeaders;
  final PrincipalAvatarImageProviderBuilder? avatarImageProviderBuilder;
  final void Function(String id, bool checked) onSelectionChanged;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (!hasMembers) return emptyState ?? const _EmptyMembers();
    if (members.isEmpty) return _NoMatches(query: query);

    final hasFooter = footer != null;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: members.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        // The footer trails the rows as the final scrolling item.
        if (hasFooter && index == members.length) return footer;
        final member = members[index];
        return _MemberRow(
          // Keyed by id, not index, so per-row state stays attached to the
          // right member when a removal shifts everyone below it up one index.
          key: ValueKey(member.id),
          principal: member,
          selected: selected.contains(member.id),
          locked: lockedIds.contains(member.id),
          avatarHeaders: avatarHeaders,
          avatarImageProviderBuilder: avatarImageProviderBuilder,
          onSelectionChanged: (checked) =>
              onSelectionChanged(member.id, checked),
          onRemove: () => onRemove(member.id),
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.principal,
    required this.selected,
    required this.locked,
    required this.avatarHeaders,
    required this.avatarImageProviderBuilder,
    required this.onSelectionChanged,
    required this.onRemove,
  });

  final Principal principal;
  final bool selected;
  final bool locked;
  final Map<String, String>? avatarHeaders;
  final PrincipalAvatarImageProviderBuilder? avatarImageProviderBuilder;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: _SelectableAvatar(
        principal: principal,
        selected: selected,
        headers: avatarHeaders,
        imageProviderBuilder: avatarImageProviderBuilder,
        // A locked member can't be bulk-removed, so checking them would offer
        // a selection no action can act on.
        onChanged: locked ? null : onSelectionChanged,
      ),
      title: Text(principal.name),
      subtitle: principal.description == null
          ? null
          : Text(
              principal.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: locked
          // A lock badge explains the missing Remove action so its absence
          // doesn't read as a bug — matching GroupListView's locked rows.
          ? Tooltip(
              message: "Locked — can't be removed",
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Remove ${principal.name}',
              onPressed: onRemove,
            ),
    );
  }
}

/// A member's avatar that doubles as its selection control: it swaps to a check
/// glyph once selected — the Google Contacts pattern for starting a
/// multi-select, and the same shape the suite's `SelectableAvatarLeading` uses.
class _SelectableAvatar extends StatelessWidget {
  const _SelectableAvatar({
    required this.principal,
    required this.selected,
    required this.headers,
    required this.imageProviderBuilder,
    required this.onChanged,
  });

  final Principal principal;
  final bool selected;
  final Map<String, String>? headers;
  final PrincipalAvatarImageProviderBuilder? imageProviderBuilder;

  /// Toggles selection, or `null` for a locked member, whose avatar is inert.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = selected
        ? CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary,
            child: Icon(Icons.check, color: scheme.onPrimary),
          )
        // The avatar labels itself with the member's name for standalone use,
        // but here the row's title and this control's own "Select …" label
        // already carry it — three announcements of one name is noise.
        : ExcludeSemantics(
            child: PrincipalAvatar(
              principal: principal,
              headers: headers,
              imageProviderBuilder: imageProviderBuilder,
            ),
          );

    if (onChanged == null) return avatar;
    return Semantics(
      checked: selected,
      label: 'Select ${principal.name}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onChanged!(!selected),
        child: avatar,
      ),
    );
  }
}

class _DeletedGroup extends StatelessWidget {
  const _DeletedGroup();

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
              Icons.help_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'This group no longer exists',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMembers extends StatelessWidget {
  const _EmptyMembers();

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
              Icons.person_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No members yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Add members to give them this group\'s access.',
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
              'No members match "$query"',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

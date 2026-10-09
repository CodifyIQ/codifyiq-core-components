import 'package:material_ui/material_ui.dart';

import 'assignment_field.dart' show resolveRoleLabel;
import 'assignment_role.dart';
import 'bulk_selection_bar.dart';
import 'group_manager_controller.dart';
import 'member_picker.dart';
import 'principal.dart';
import 'principal_avatar.dart';
import 'role_filter_bar.dart';
import 'role_menu.dart';

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
/// ## Roles
///
/// Pass [roles] to qualify each membership — e.g. a group's *owner* versus a
/// plain *member* — using the same contract as [MemberAssignmentField.roles].
/// Each row then shows its role from [rolesById] as a trailing `Owner ▾`
/// action beside Remove; tapping it opens a menu of the roles with the current
/// one checked, and a pick is reported through [onRoleChanged]. With members
/// selected, the selection bar gains a "Set role" action that applies one role
/// to every selected member in a single [onRoleChanged] call. Members the
/// picker adds are reported through [onMembersAdded] first, then through
/// [onRoleChanged] with [defaultRoleId]. Locked rows show their role but can't
/// change it. The view never stores roles: apply each change to [rolesById].
///
/// With roles on, a row of chips beneath the search field narrows the list to
/// one role — "who owns this group?" — and combines with the search. Selecting
/// all selects only the members shown, and switching the filter drops any
/// selected member it hides, so bulk actions apply to what is on screen.
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
    this.roles = const <AssignmentRole>[],
    this.rolesById = const <String, String>{},
    this.defaultRoleId,
    this.onRoleChanged,
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

  /// The roles a membership may carry, in the order the role menu lists them.
  /// Empty (the default) turns roles off entirely: rows show no role and the
  /// view behaves exactly as without roles.
  final List<AssignmentRole> roles;

  /// The current role id of each member, keyed by member id. A member missing
  /// from this map shows "Set role" in place of a role but still opens the menu,
  /// with nothing checked, so it can be given one; a role id that isn't in
  /// [roles] shows the raw id and can still be changed. Ignored when [roles] is
  /// empty.
  final Map<String, String> rolesById;

  /// The role a member newly added through the picker starts with: after
  /// [onMembersAdded], [onRoleChanged] fires with the added ids and this role.
  /// `null` reports no role, leaving new rows role-less until the user picks
  /// one. Must be the id of one of [roles].
  final String? defaultRoleId;

  /// Called with the affected member ids and their new role id — one id when
  /// picked from a row's menu, the whole selection from the bulk "Set role"
  /// action, or the picker's additions with [defaultRoleId].
  ///
  /// The view never stores roles itself; apply the change to [rolesById].
  /// When `null`, roles are display-only.
  final void Function(Set<String> ids, String roleId)? onRoleChanged;

  @override
  State<GroupMembersView> createState() => _GroupMembersViewState();
}

class _GroupMembersViewState extends State<GroupMembersView> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// The role id the list is narrowed to, or `null` for every member.
  String? _roleFilter;

  /// Ids checked for bulk removal. Cleared once applied.
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    final defaultRoleId = widget.defaultRoleId;
    assert(
      widget.roles.isEmpty ||
          defaultRoleId == null ||
          widget.roles.any((role) => role.id == defaultRoleId),
      'defaultRoleId must be the id of one of roles',
    );
  }

  @override
  void didUpdateWidget(GroupMembersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A role change made outside this view — a sync, another admin — can move
    // a selected member out of the filter. Drop it, so bulk actions never reach
    // a member that is no longer shown.
    final roleFilter = _activeRoleFilter?.id;
    if (roleFilter != null && widget.rolesById != oldWidget.rolesById) {
      _selected.removeWhere((id) => widget.rolesById[id] != roleFilter);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  GroupManagerController get _controller =>
      widget.controller ?? GroupManagerScope.of(context, listen: false);

  /// The group's members, in roster order, plus a placeholder for any member id
  /// the roster doesn't cover — surfacing the gap rather than hiding the
  /// assignment. Filtered by the current search query and role filter.
  List<Principal> _members(Set<String> memberIds, String? roleFilter) {
    final known = {for (final p in widget.roster) p.id};
    final resolved = <Principal>[
      for (final principal in widget.roster)
        if (memberIds.contains(principal.id)) principal,
      for (final id in memberIds)
        if (!known.contains(id))
          Principal(id: id, name: id, description: 'Not in the roster'),
    ];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty && roleFilter == null) return resolved;
    return [
      for (final principal in resolved)
        if ((roleFilter == null ||
                widget.rolesById[principal.id] == roleFilter) &&
            (principal.name.toLowerCase().contains(q) ||
                (principal.description?.toLowerCase().contains(q) ?? false)))
          principal,
    ];
  }

  /// The role filter in effect: `null` when unset, or when the view's roles no
  /// longer offer the chosen role — so a stale filter can't hide every row
  /// behind a chip that is no longer shown.
  AssignmentRole? get _activeRoleFilter {
    for (final role in widget.roles) {
      if (role.id == _roleFilter) return role;
    }
    return null;
  }

  void _setRoleFilter(String? roleId) {
    setState(() {
      _roleFilter = roleId;
      // Bulk actions apply to the members shown, so drop any selected member
      // the new filter hides.
      if (roleId != null) {
        _selected.removeWhere((id) => widget.rolesById[id] != roleId);
      }
    });
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

    // Like the fields, the view never stores roles: it reports the default
    // role for each newly added member and leaves applying it to the caller.
    final defaultRoleId = widget.defaultRoleId;
    final onRoleChanged = widget.onRoleChanged;
    if (added.isNotEmpty &&
        widget.roles.isNotEmpty &&
        defaultRoleId != null &&
        onRoleChanged != null) {
      onRoleChanged(added, defaultRoleId);
    }
  }

  /// Whether roles can be changed from this surface: roles are on and a
  /// listener is wired. Locked rows are excluded separately, per row.
  bool get _canChangeRoles =>
      widget.roles.isNotEmpty && widget.onRoleChanged != null;

  void _setRole(Set<String> ids, String roleId) {
    if (ids.isEmpty) return;
    setState(() => _selected.removeAll(ids));
    widget.onRoleChanged?.call(ids, roleId);
  }

  /// The role shared by every selected member, so the bulk menu can check it;
  /// `null` when the selection is mixed or any member has no role.
  String? _commonRoleId() {
    String? common;
    for (final id in _selected) {
      final roleId = widget.rolesById[id];
      if (roleId == null || (common != null && roleId != common)) return null;
      common = roleId;
    }
    return common;
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
          final roleFilter = _activeRoleFilter;
          final members = _members(memberIds, roleFilter?.id);
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
              if (widget.roles.isNotEmpty && memberIds.isNotEmpty) ...[
                RoleFilterBar(
                  roles: widget.roles,
                  selectedRoleId: roleFilter?.id,
                  onChanged: _setRoleFilter,
                ),
                const SizedBox(height: 8),
              ],
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
                    if (_canChangeRoles)
                      RoleMenu(
                        roles: widget.roles,
                        currentRoleId: _commonRoleId(),
                        onSelected: (roleId) =>
                            _setRole(Set.of(_selected), roleId),
                        builder: (onRolePressed) => IconButton(
                          tooltip: 'Set role',
                          icon: const Icon(Icons.badge_outlined),
                          onPressed: onRolePressed,
                        ),
                      ),
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
                  roleFilterLabel: roleFilter?.label,
                  selected: _selected,
                  lockedIds: widget.lockedMemberIds,
                  emptyState: widget.emptyState,
                  footer: widget.footer,
                  avatarHeaders: widget.avatarHeaders,
                  avatarImageProviderBuilder: widget.avatarImageProviderBuilder,
                  roles: widget.roles,
                  rolesById: widget.rolesById,
                  onRoleChanged: _canChangeRoles
                      ? (id, roleId) => _setRole(<String>{id}, roleId)
                      : null,
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
    required this.roleFilterLabel,
    required this.selected,
    required this.lockedIds,
    required this.emptyState,
    required this.footer,
    required this.avatarHeaders,
    required this.avatarImageProviderBuilder,
    required this.roles,
    required this.rolesById,
    required this.onRoleChanged,
    required this.onSelectionChanged,
    required this.onRemove,
  });

  final List<Principal> members;
  final bool hasMembers;
  final String query;

  /// Label of the role the list is narrowed to, or `null` when unfiltered.
  final String? roleFilterLabel;
  final Set<String> selected;
  final Set<String> lockedIds;
  final Widget? emptyState;
  final Widget? footer;
  final Map<String, String>? avatarHeaders;
  final PrincipalAvatarImageProviderBuilder? avatarImageProviderBuilder;
  final List<AssignmentRole> roles;
  final Map<String, String> rolesById;

  /// `null` when roles are off or display-only.
  final void Function(String id, String roleId)? onRoleChanged;
  final void Function(String id, bool checked) onSelectionChanged;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (!hasMembers) return emptyState ?? const _EmptyMembers();
    if (members.isEmpty) {
      return _NoMatches(query: query, roleLabel: roleFilterLabel);
    }

    final hasFooter = footer != null;
    // Every label a row's role slot can show, so each row reserves the width of
    // the widest and the roles form one column.
    final roleLabels = [
      for (final role in roles) role.label,
      if (roles.isNotEmpty && onRoleChanged != null) 'Set role',
    ];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: members.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        // The footer trails the rows as the final scrolling item.
        if (hasFooter && index == members.length) return footer;
        final member = members[index];
        final onRoleChanged = this.onRoleChanged;
        return _MemberRow(
          // Keyed by id, not index, so per-row state stays attached to the
          // right member when a removal shifts everyone below it up one index.
          key: ValueKey(member.id),
          principal: member,
          selected: selected.contains(member.id),
          locked: lockedIds.contains(member.id),
          avatarHeaders: avatarHeaders,
          avatarImageProviderBuilder: avatarImageProviderBuilder,
          roleLabels: roleLabels,
          roleLabel: resolveRoleLabel(roles, rolesById, member.id),
          roleMenu: onRoleChanged == null
              ? null
              : (builder) => RoleMenu(
                  roles: roles,
                  currentRoleId: rolesById[member.id],
                  onSelected: (roleId) => onRoleChanged(member.id, roleId),
                  builder: builder,
                ),
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
    required this.roleLabels,
    required this.roleLabel,
    required this.roleMenu,
    required this.onSelectionChanged,
    required this.onRemove,
  });

  final Principal principal;
  final bool selected;
  final bool locked;
  final Map<String, String>? avatarHeaders;
  final PrincipalAvatarImageProviderBuilder? avatarImageProviderBuilder;

  /// Every label the view's role slots can show; empty when the view has no
  /// roles, which renders no role affordance.
  final List<String> roleLabels;

  /// This member's resolved role label, or `null` for a member with no role.
  final String? roleLabel;

  /// Wraps the role action in its menu, or `null` when roles are display-only.
  final Widget Function(Widget Function(VoidCallback onRolePressed) builder)?
  roleMenu;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onRemove;

  /// The `Owner ▾` role action, padded like [_RoleLabel] so editable and
  /// read-only roles start at the same position.
  static Widget _roleButton(
    Widget label,
    VoidCallback? onPressed,
    EdgeInsetsGeometry padding,
  ) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(padding: padding),
    icon: const Icon(Icons.arrow_drop_down, size: 18),
    iconAlignment: IconAlignment.end,
    label: label,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildTile(context, stacked: constraints.maxWidth < _stackRoleBelow),
    );
  }

  /// Builds the row with its role trailing beside Remove, or — when [stacked],
  /// on a tile too narrow for both beside the name — on a line under the name,
  /// where every row's role still starts at the same edge.
  Widget _buildTile(BuildContext context, {required bool stacked}) {
    final theme = Theme.of(context);
    final roleMenu = this.roleMenu;
    final padding = stacked ? _stackedRolePadding : _rolePadding;
    // A locked row — or a display-only view — shows its role read-only.
    final Widget roleChild = locked || roleMenu == null
        ? _RoleLabel(
            roleLabel: roleLabel,
            name: principal.name,
            padding: padding,
          )
        : roleMenu(
            (onRolePressed) => _roleButton(
              Semantics(
                label: roleLabel == null
                    ? '${principal.name}, no role, change role'
                    : '${principal.name}, $roleLabel, change role',
                excludeSemantics: true,
                child: _roleText(roleLabel ?? 'Set role'),
              ),
              onRolePressed,
              padding,
            ),
          );
    final Widget? role = roleLabels.isEmpty
        ? null
        : stacked
        ? roleChild
        : ConstrainedBox(
            // Capped so one long label can't squeeze every row's title; a
            // label past the cap ellipsizes, and its semantics keep it whole.
            constraints: const BoxConstraints(maxWidth: _maxRoleWidth),
            child: _SizedLike(
              alignment: AlignmentDirectional.centerStart,
              // An editable view's slot is as wide as its widest role button,
              // so a locked row's read-only role starts where the buttons do.
              sizers: [
                for (final label in roleLabels)
                  roleMenu == null
                      ? _RoleLabel(
                          roleLabel: label,
                          name: principal.name,
                          padding: padding,
                        )
                      : _roleButton(_roleText(label), null, padding),
              ],
              child: roleChild,
            ),
          );
    final Widget action = locked
        // A lock badge explains the missing Remove action so its absence
        // doesn't read as a bug — matching GroupListView's locked rows. It
        // takes the Remove button's space so the column above stays aligned.
        ? _SizedLike(
            alignment: Alignment.center,
            sizers: const [
              IconButton(
                icon: Icon(Icons.person_remove_outlined),
                onPressed: null,
              ),
            ],
            child: Tooltip(
              message: "Locked — can't be removed",
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : IconButton(
            icon: const Icon(Icons.person_remove_outlined),
            tooltip: 'Remove ${principal.name}',
            onPressed: onRemove,
          );
    final description = principal.description;
    final Widget? descriptionText = description == null
        ? null
        : Text(description, maxLines: 1, overflow: TextOverflow.ellipsis);
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
      subtitle: stacked && role != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [?descriptionText, role],
            )
          : descriptionText,
      trailing: role == null || stacked
          ? action
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [role, const SizedBox(width: 4), action],
            ),
    );
  }
}

/// Below this tile width a row's role moves from beside Remove to under the
/// name: beside it, the widest role slot and Remove would leave the name too
/// little room — or none, which [ListTile] rejects.
const _stackRoleBelow = 320.0;

/// Role padding on a stacked row: no leading inset, so the role text lines up
/// with the name above it.
const _stackedRolePadding = EdgeInsetsDirectional.fromSTEB(0, 4, 8, 4);

/// The widest a row's role slot grows. Fits labels like "Administrator" or
/// "Can manage"; anything longer ellipsizes rather than narrowing the titles.
const _maxRoleWidth = 140.0;

/// A role label held to one line, ellipsized past [_maxRoleWidth].
Text _roleText(String label, {TextStyle? style}) =>
    Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);

/// Padding shared by a row's role button and its read-only role label, so the
/// role text starts at the same position either way.
const _rolePadding = EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8);

/// Lays out [child] in the space the largest of [sizers] would take, so rows
/// with different content keep their trailing columns aligned.
///
/// Only [child] is painted, hit-tested, and exposed to semantics; the sizers
/// are laid out for their size alone.
class _SizedLike extends StatelessWidget {
  const _SizedLike({
    required this.alignment,
    required this.sizers,
    required this.child,
  });

  final AlignmentGeometry alignment;
  final List<Widget> sizers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      alignment: alignment,
      index: 0,
      children: [child, ...sizers],
    );
  }
}

/// A member's role shown read-only — on a locked row, or when the view has no
/// `onRoleChanged` — de-emphasized like the role on a chip.
class _RoleLabel extends StatelessWidget {
  const _RoleLabel({
    required this.roleLabel,
    required this.name,
    required this.padding,
  });

  final String? roleLabel;
  final String name;

  /// Matches the role button's padding, so the two start at the same position.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = roleLabel;
    if (label == null) return const SizedBox.shrink();
    return Semantics(
      label: '$name, $label',
      excludeSemantics: true,
      child: Padding(
        padding: padding,
        child: _roleText(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
  const _NoMatches({required this.query, required this.roleLabel});

  final String query;

  /// Label of the active role filter, or `null` when only the search narrows.
  final String? roleLabel;

  String get _message {
    final roleLabel = this.roleLabel;
    if (roleLabel == null) return 'No members match "$query"';
    if (query.isEmpty) return 'No members with the role "$roleLabel"';
    return 'No members with the role "$roleLabel" match "$query"';
  }

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
              _message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

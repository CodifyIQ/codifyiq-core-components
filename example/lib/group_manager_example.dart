import 'dart:convert';

import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:codifyiq_user_avatar/codifyiq_user_avatar.dart';
import 'package:flutter/material.dart';

/// Demo for [GroupManagerController], [GroupManagerView], [GroupMembersView],
/// [GroupAssignmentField], [GroupBulkAssignmentDialog], [BulkSelectionBar],
/// and [SelectableAvatarLeading] (from `codifyiq_user_avatar`).
///
/// The first tab manages the group catalog (create / edit / delete), and
/// tapping any group row drills into a [GroupMembersView] for that group —
/// the group-side mirror of the second tab. Membership is one relation viewed
/// from two ends: adding Grace to "Editors" from the group's member list is
/// the same edit as adding an "Editors" chip to Grace's row on the Members
/// tab, and each is immediately visible from the other. That drill-down also
/// shows a locked *member* (Ada owns "Administrators", so she can't be removed
/// from it) — the member-side counterpart of the locked group below. The
/// second tab assigns one or more of those groups to a handful of demo users via
/// removable chips and a searchable picker, rendered with `singleLine: true`
/// so each row stays compact — name, chips, and the edit button share one
/// line, with overflow collapsing behind "+N more". Each row leads with a
/// [SelectableAvatarLeading] — an avatar that's tappable, or swaps to a check
/// icon on hover (or permanently once selected), the Google Contacts pattern
/// for starting a multi-select — and ends with a kebab menu offering
/// "Delete" for that one member. Those avatars show each member's photo from
/// whichever source their `Principal` carries (a URL, or in-memory bytes via
/// `imageProvider`), exactly as the group's member list does, with a footer
/// note under the list spelling the sources out. A [BulkSelectionBar] above the list is
/// always present, at a fixed height, so checking or clearing members never
/// reflows the list: its Gmail-style selector (tristate checkbox + "All"/
/// "None" dropdown) sits at its start, always interactive since it's how a
/// selection gets started in the first place, while three `actions` at its
/// end — icon buttons (tooltipped "Add groups" / "Remove groups") plus a
/// kebab menu offering bulk "Delete" — stay reserved-but-invisible until at
/// least one member is checked. "Add groups"
/// opens [GroupBulkAssignmentDialog.show] and applies the result via
/// [GroupManagerController.assignMany]; "Remove groups" opens
/// [GroupBulkAssignmentDialog.showRemoval], scoped to only the groups the
/// checked members actually hold, and applies it via
/// [GroupManagerController.unassignMany]. Both delete paths — per-row and
/// bulk — confirm first, then clear the deleted member(s)' group assignments
/// before dropping them from the roster. The third shows the per-target field
/// attaching groups to a *non-user* target — folders — where the choices are
/// scoped to only the groups the signed-in user belongs to, and the
/// "Administrators" group is locked so admins always retain access to every
/// folder and cannot be removed. The same lock protects "Administrators" in the
/// catalog tab, where it offers no Delete action, and in the Members tab's bulk
/// removal, where it's excluded from the offered groups entirely — so the
/// permanent group the folders rely on can't be deleted out from under them by
/// any path. All three tabs are driven by a single UI-only controller — edits
/// on one are reflected on the others.
class GroupManagerExample extends StatefulWidget {
  /// Creates a [GroupManagerExample].
  const GroupManagerExample({super.key});

  @override
  State<GroupManagerExample> createState() => _GroupManagerExampleState();
}

class _GroupManagerExampleState extends State<GroupManagerExample> {
  final GroupManagerController _controller = GroupManagerController(
    groups: const [
      Group(
        id: 'admins',
        name: 'Administrators',
        description: 'Full access to every setting.',
        color: GroupColor.primary,
        icon: Icons.admin_panel_settings,
      ),
      Group(
        id: 'editors',
        name: 'Editors',
        description: 'Can create and edit content.',
        color: GroupColor.secondary,
        icon: Icons.edit_note,
      ),
      Group(
        id: 'viewers',
        name: 'Viewers',
        description: 'Read-only access.',
        color: GroupColor.tertiary,
        icon: Icons.visibility,
      ),
      Group(
        id: 'billing',
        name: 'Billing',
        description: 'Manage invoices and subscriptions.',
        color: GroupColor.neutral,
        icon: Icons.receipt_long,
      ),
    ],
    assignments: {
      // Ada belongs to every group so her single-line row on the Members tab
      // overflows out of the box — the "+N more" affordance is visible
      // without needing to add a group first (how many chips fit depends on
      // window width, so the exact count varies).
      'ada': {'admins', 'editors', 'viewers', 'billing'},
      'grace': {'editors'},
      // Katherine's photo comes from memory rather than a URL, so the group's
      // member list shows that path rendering beside the network ones.
      'katherine': {'viewers'},
      // A deliberately long name, so the single-line row's fit calculation is
      // visible under real pressure — the label eats into the width left over
      // for chips.
      'margaret': {'editors', 'viewers'},
      // Pre-share a couple of folders so the locked "Administrators" chip sits
      // next to a removable "Editors" chip — making the contrast between the
      // two obvious. "Contracts" is left unshared to show a folder with only
      // the locked chip.
      'folder:reports': {'editors'},
      'folder:designs': {'editors'},
    },
  );

  /// Permanent groups: locked on every folder (always have access, can't be
  /// unshared) and protected in the catalog (no Delete action), so the group
  /// the folders depend on can't be deleted.
  static const Set<String> _lockedGroups = {'admins'};

  /// A tiny in-memory PNG (a solid red 1×1 swatch), decoded once and held as a
  /// stable [MemoryImage] instance.
  ///
  /// Decoding here rather than inside `build` is what makes
  /// [Principal.imageProvider] usable in a list: `MemoryImage` compares its
  /// bytes by identity, so a `MemoryImage(base64Decode(...))` allocated per
  /// frame would make every [Principal] compare unequal and re-decode the photo
  /// on each rebuild.
  static final MemoryImage _inMemoryPhoto = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
      'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    ),
  );

  // Not `const`: a decoded photo can't be, which is the constraint every
  // caller of Principal.imageProvider runs into.
  static final List<Principal> _seedRoster = [
    // A real photo, so the member surfaces exercise the image path rather than
    // only the initials fallback.
    const Principal(
      id: 'ada',
      name: 'Ada Lovelace',
      description: 'ada@example.com',
      imageUrl: 'https://picsum.photos/id/1027/200/200',
    ),
    const Principal(
      id: 'grace',
      name: 'Grace Hopper',
      description: 'grace@example.com',
      imageUrl: 'https://picsum.photos/id/1005/200/200',
    ),
    // A photo that never was a URL — bytes straight from memory, the shape a
    // base64 payload from a directory or backend takes. It renders through the
    // same circular clip as the network photos above.
    Principal(
      id: 'katherine',
      name: 'Katherine Johnson',
      description: 'katherine@example.com',
      imageProvider: _inMemoryPhoto,
    ),
    // A broken URL, so the fall-back-to-initials path stays visible too.
    const Principal(
      id: 'linus',
      name: 'Linus Torvalds',
      description: 'linus@example.com',
      imageUrl: 'https://invalid.example.com/nope.png',
    ),
    const Principal(
      id: 'margaret',
      // A deliberately long name, so the single-line row's fit calculation is
      // visible under real pressure — the label eats into the width left over
      // for chips.
      //
      // The bracketed qualifier also covers the initials path: it is stripped,
      // so this reads "MH", not "M[".
      name: 'Margaret Eleanor Hamilton-Fitzgerald [Contractor]',
      description: 'margaret@example.com',
    ),
  ];

  /// Permanent members: "Ada" owns the Administrators group, so she can't be
  /// removed from it — the member-side counterpart of a locked group.
  static const Map<String, Set<String>> _lockedMembers = {
    'admins': {'ada'},
  };

  /// The demo roster, owned here so both the Members tab (which can delete a
  /// member) and the group drill-down (which offers members to add) see the
  /// same people.
  late final List<Principal> _roster = List.of(_seedRoster);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Deleting a member is purely a demo-roster concern — the package has no
  /// notion of "users" to delete — but their assignments are still real
  /// controller data, so clear those too rather than leaving them orphaned.
  void _deleteMembers(Set<String> ids) {
    for (final id in ids) {
      _controller.setAssignments(id, const <String>{});
    }
    setState(() => _roster.removeWhere((p) => ids.contains(p.id)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Group Manager Example'),
          actions: const [BrightnessButton()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Groups'),
              Tab(text: 'Members'),
              Tab(text: 'Apply groups'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GroupsTab(
              controller: _controller,
              roster: _roster,
              lockedGroups: _lockedGroups,
              lockedMembers: _lockedMembers,
            ),
            _MembersTab(
              controller: _controller,
              roster: _roster,
              lockedGroups: _lockedGroups,
              onDeleteMembers: _deleteMembers,
            ),
            _FoldersTab(
              controller: _controller,
              currentUserId: 'ada',
              lockedGroups: _lockedGroups,
            ),
          ],
        ),
      ),
    );
  }
}

/// The catalog tab: a drop-in [GroupManagerView] plus a footer note explaining
/// why "Administrators" has no delete action.
///
/// Tapping a row drills into that group's membership with a [GroupMembersView]
/// — the group-side mirror of the Members tab. The two edit the same
/// assignment data from opposite ends: add Grace to "Editors" here and her row
/// on the Members tab gains an "Editors" chip, and vice versa.
class _GroupsTab extends StatelessWidget {
  const _GroupsTab({
    required this.controller,
    required this.roster,
    required this.lockedGroups,
    required this.lockedMembers,
  });

  final GroupManagerController controller;

  /// Everyone who could be added to a group. The controller stores ids only —
  /// it has no roster of its own — so the caller supplies one.
  final List<Principal> roster;

  final Set<String> lockedGroups;

  /// Per-group members that can't be removed, e.g. a group's owner.
  final Map<String, Set<String>> lockedMembers;

  void _openMembers(BuildContext context, Group group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: const [BrightnessButton()],
          ),
          body: GroupMembersView(
            // Keyed by id, not by the Group value: renaming the group
            // elsewhere is reflected here rather than showing a stale name.
            groupId: group.id,
            roster: roster,
            controller: controller,
            lockedMemberIds: lockedMembers[group.id] ?? const <String>{},
            footer: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _FooterNote(
                lockedMembers.containsKey(group.id)
                    ? 'Ada owns this group, so her row is locked: no remove '
                          'action, not selectable for a bulk removal, and '
                          'checked-and-disabled in the picker. Everyone else '
                          'can be removed. Whether a membership is permanent '
                          'is your app\'s decision — the widget takes a '
                          '`lockedMemberIds` set and renders the result.'
                    : 'Adding or removing members here writes the same '
                          'assignment data the Members tab reads — the two '
                          'are mirror images of one relation, not separate '
                          'stores. Switch tabs after a change to see it.',
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The note rides along as the catalog's footer, so it sits directly under
    // the last group and scrolls with the list rather than pinning to the
    // bottom of the pane.
    return GroupManagerView(
      controller: controller,
      lockedIds: lockedGroups,
      onTap: (group) => _openMembers(context, group),
      footer: const Padding(
        padding: EdgeInsets.only(top: 12),
        child: _FooterNote(
          'Tap any group to manage its members. '
          '"Administrators" is locked, so its row offers no delete — the '
          'permanent group your assignments depend on can\'t be removed from '
          'the catalog (it stays editable). Every other group can be deleted. '
          'This demo hard-codes that single locked group, but which groups are '
          'locked, and how that set is derived, is entirely up to your app — a '
          "constant, the signed-in user's role, a per-resource policy, whatever "
          'fits. The widget takes a `lockedIds` set and withholds the delete '
          'action; it does not decide what is locked.',
        ),
      ),
    );
  }
}

class _MembersTab extends StatefulWidget {
  const _MembersTab({
    required this.controller,
    required this.roster,
    required this.lockedGroups,
    required this.onDeleteMembers,
  });

  final GroupManagerController controller;

  /// The demo roster, owned by the parent so the group drill-down on the
  /// Groups tab offers exactly the people this tab lists.
  final List<Principal> roster;

  /// Groups that can never be bulk-removed — see [GroupBulkAssignmentDialog.showRemoval].
  final Set<String> lockedGroups;

  /// Drops members from the shared roster and clears their assignments.
  final ValueChanged<Set<String>> onDeleteMembers;

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// Ids checked for bulk assignment. Cleared once applied.
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _bulkAssign(BuildContext context) async {
    final ids = await GroupBulkAssignmentDialog.show(
      context,
      groups: widget.controller.groups,
      principalCount: _selected.length,
    );
    if (ids == null) return;
    widget.controller.assignMany(_selected, ids);
    setState(_selected.clear);
  }

  Future<void> _bulkRemove(BuildContext context, List<Group> removable) async {
    final ids = await GroupBulkAssignmentDialog.showRemoval(
      context,
      groups: removable,
      principalCount: _selected.length,
      lockedIds: widget.lockedGroups,
    );
    if (ids == null) return;
    widget.controller.unassignMany(_selected, ids);
    setState(_selected.clear);
  }

  /// Whether every currently-visible (search-filtered) member is checked.
  bool _allVisibleSelected(List<Principal> visible) =>
      visible.isNotEmpty && visible.every((p) => _selected.contains(p.id));

  /// Selects every currently-visible member, or clears the selection
  /// entirely — "None" always clears everything, even a member checked
  /// while a search filter hid the rest, matching Gmail's "Select: None".
  void _setSelection(List<Principal> visible, {required bool selectAll}) {
    if (selectAll) {
      _selected.addAll(visible.map((p) => p.id));
    } else {
      _selected.clear();
    }
  }

  Future<void> _deleteWithConfirmation(
    BuildContext context,
    Set<String> ids,
  ) async {
    if (!await _confirmDelete(context, ids.length)) return;
    widget.onDeleteMembers(ids);
    setState(() => _selected.removeAll(ids));
  }

  Future<bool> _confirmDelete(BuildContext context, int count) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              count == 1 ? 'Delete member?' : 'Delete $count members?',
            ),
            content: const Text('This also removes their group memberships.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// The rightmost "more actions" affordance shared by both the group action
  /// bar and every row — a single "Delete" item styled with the error color.
  Widget _kebabMenu({required String tooltip, required VoidCallback onDelete}) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: (_) => onDelete(),
      // Left at the default (non-error) color here — the destructive cue
      // belongs on the confirmation dialog's "Delete" button, not on every
      // menu entry that could lead to it.
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 12),
              Text('Delete'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final users = q.isEmpty
        ? widget.roster
        : widget.roster.where((p) => p.name.toLowerCase().contains(q)).toList();

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        // Only offer removing groups at least one checked member actually
        // has — offering the full catalog would let "removing" a group
        // nobody in the selection holds do nothing, which reads as broken.
        // Locked groups are excluded too, matching what showRemoval itself
        // filters, so the button disables rather than opening an empty
        // picker when the only held group among the selection is locked.
        final heldByAnySelected = <String>{
          for (final id in _selected) ...widget.controller.groupsFor(id),
        };
        final removableGroups = [
          for (final group in widget.controller.groups)
            if (heldByAnySelected.contains(group.id) &&
                !widget.lockedGroups.contains(group.id))
              group,
        ];
        // Cap the content to a comfortable measure and center it on wide panes
        // (M3 large-screen guidance), matching GroupManagerView's default.
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              // Let the search bar fill its pane (M3: scale with the layout,
              // stay close to the content it filters) — matching the Groups tab.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: SearchBar(
                    controller: _search,
                    hintText: 'Search members',
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll(0),
                    trailing: [
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                    ],
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                // Always present (rather than conditional on a selection) so
                // checking or clearing the first/last member doesn't reflow
                // the list beneath it. The left/right inset (32 = the 16
                // ListView padding + the 16 card padding, now that Card's own
                // margin is zeroed) lines BulkSelectionBar's checkbox and the
                // kebab menu up with every row's own leading/trailing control.
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
                  child: BulkSelectionBar(
                    selectedCount: _selected.length,
                    allVisibleSelected: _allVisibleSelected(users),
                    emptyLabel: 'No members selected',
                    onSelectAll: (choice) => setState(
                      () => _setSelection(
                        users,
                        selectAll: choice == BulkSelectAll.all,
                      ),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Remove groups',
                        onPressed: removableGroups.isEmpty
                            ? null
                            : () => _bulkRemove(context, removableGroups),
                        icon: const Icon(Icons.group_remove_outlined),
                      ),
                      IconButton(
                        tooltip: 'Add groups',
                        onPressed: () => _bulkAssign(context),
                        icon: const Icon(Icons.group_add_outlined),
                      ),
                      _kebabMenu(
                        tooltip: 'More actions',
                        onDelete: () =>
                            _deleteWithConfirmation(context, Set.of(_selected)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: users.isEmpty
                      ? Center(
                          child: Text(
                            'No members match "${_query.trim()}"',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          // One extra item for the footer note, so it sits
                          // directly under the last member and scrolls with
                          // the list — matching the catalog tab's footer.
                          itemCount: users.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            if (index == users.length) {
                              return const _AvatarNote();
                            }
                            final user = users[index];
                            return Card(
                              // Keyed by id, not index, so per-row state
                              // (e.g. SelectableAvatarLeading's hover flag)
                              // stays attached to the right member when a
                              // delete shifts everyone below it up one index.
                              key: ValueKey(user.id),
                              // Zeroed so the row's horizontal inset is just
                              // the ListView padding plus this card's own
                              // padding — a predictable total the toolbar
                              // above matches to keep both aligned.
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  // Center rather than top-align: with
                                  // singleLine, the field's content is always
                                  // exactly one row tall — close enough to
                                  // the 40dp avatar/check-icon leading that
                                  // there's no multi-line chip wrap to align
                                  // against.
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SelectableAvatarLeading(
                                      displayName: user.name,
                                      // The same photo the group's member list
                                      // shows for this user, from whichever
                                      // source it came — a member looks the
                                      // same viewed from either end of the
                                      // relation.
                                      photoUrl: user.imageUrl,
                                      imageProvider: user.imageProvider,
                                      selected: _selected.contains(user.id),
                                      onChanged: (checked) => setState(() {
                                        if (checked) {
                                          _selected.add(user.id);
                                        } else {
                                          _selected.remove(user.id);
                                        }
                                      }),
                                    ),
                                    // The avatar/check-icon fills its 40x40
                                    // box edge-to-edge (unlike a bare
                                    // Checkbox, which has built-in tap-target
                                    // padding), so it needs an explicit gap
                                    // before the name to avoid crowding it.
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GroupAssignmentField(
                                        label: user.name,
                                        groups: widget.controller.groups,
                                        selected: widget.controller.groupsFor(
                                          user.id,
                                        ),
                                        onChanged: (ids) => widget.controller
                                            .setAssignments(user.id, ids),
                                        // Editing a person's memberships
                                        // reads better with a "manage user"
                                        // glyph than a pencil.
                                        editIcon:
                                            Icons.manage_accounts_outlined,
                                        editLabel: 'Edit groups',
                                        pickerTitle:
                                            'Assign groups to ${user.name}',
                                        // Grid-like member list: name, chips,
                                        // and the edit button share one row
                                        // per person, and only as many chips
                                        // as the row is wide enough for are
                                        // shown — so far more members fit on
                                        // screen than the stacked layout
                                        // allows.
                                        singleLine: true,
                                      ),
                                    ),
                                    _kebabMenu(
                                      tooltip: 'More actions',
                                      onDelete: () => _deleteWithConfirmation(
                                        context,
                                        {user.id},
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Attaches groups to a non-user target — folders.
///
/// Demonstrates the reusable [GroupAssignmentField] pointed at an arbitrary
/// object: each folder is keyed by `'folder:<id>'` in the same controller, and
/// the offered groups are scoped to only those the signed-in user belongs to —
/// you can share a folder with your own groups, but not ones you lack.
///
/// Administrators are locked on every folder: they always have access and the
/// chip can't be removed — the canonical "this group always has access to every
/// resource" case.
class _FoldersTab extends StatelessWidget {
  const _FoldersTab({
    required this.controller,
    required this.currentUserId,
    required this.lockedGroups,
  });

  final GroupManagerController controller;
  final String currentUserId;

  /// Groups that always have access to every folder, regardless of sharing.
  final Set<String> lockedGroups;

  static const List<({String id, String name, IconData icon})> _folders = [
    (id: 'reports', name: 'Quarterly Reports', icon: Icons.folder_outlined),
    (id: 'designs', name: 'Product Designs', icon: Icons.folder_outlined),
    (id: 'contracts', name: 'Contracts', icon: Icons.folder_outlined),
  ];

  Widget _folderCard(
    BuildContext context,
    ({String id, String name, IconData icon}) folder,
    List<Group> grantable,
  ) {
    final shared = controller.groupsFor('folder:${folder.id}');
    final grantableIds = grantable.map((g) => g.id).toSet();
    // Offer what the signer can grant, plus anything already shared with this
    // folder, plus the always-shared groups so their locked chips render even
    // if the signer can't otherwise grant them. Without the first two an
    // existing share would orphan: gone from both the chips and the picker, yet
    // still in the data.
    final offered = <Group>[
      for (final group in controller.groups)
        if (grantableIds.contains(group.id) ||
            shared.contains(group.id) ||
            lockedGroups.contains(group.id))
          group,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GroupAssignmentField(
          label: folder.name,
          groups: offered,
          selected: shared,
          lockedIds: lockedGroups,
          onChanged: (ids) =>
              controller.setAssignments('folder:${folder.id}', ids),
          // Granting a folder access — the default group-add glyph fits, but
          // relabel the action to read as access rather than membership.
          editLabel: 'Manage access',
          pickerTitle: 'Share "${folder.name}" with your groups',
          emptyHint: 'Not shared with any of your groups',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // The choices are scoped to the signed-in user's own groups — what they
        // are allowed to grant — not the whole catalog.
        final grantable = controller.resolvedGroupsFor(currentUserId);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'An example of applying existing groups to objects in your '
                  'application. Here, the signed-in user shares folders with the '
                  'groups they belong to.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: ListTile(
                    leading: const Icon(Icons.account_circle_outlined),
                    title: const Text('Signed in as Ada Lovelace'),
                    subtitle: Text(
                      grantable.isEmpty
                          ? 'You belong to no groups, so there is nothing to share.'
                          : 'You can share folders with the groups you belong to: '
                                '${grantable.map((g) => g.name).join(', ')}.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final folder in _folders) ...[
                  _folderCard(context, folder, grantable),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                const _FooterNote(
                  'Above, "Administrators" is locked: its chip has no remove '
                  'affordance here (and its catalog row offers no delete), so '
                  'admins keep access to every folder. The other chips are '
                  'removable. This demo hard-codes that single locked group, but '
                  'which groups are locked, and how that set is derived, is '
                  "entirely up to your app — a constant, the signed-in user's "
                  'role, a per-resource policy, whatever fits. The widgets take '
                  'a `lockedIds` set and render the result; they do not decide '
                  'what is locked.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The Members tab's footer note: where a member's avatar comes from.
///
/// Rides the list as its final item, in the same low-emphasis style as the
/// locking notes, because the answer has the same shape — the widgets render
/// the photo you hand them and fetch nothing you didn't ask for.
class _AvatarNote extends StatelessWidget {
  const _AvatarNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 12),
      child: _FooterNote(
        'Every avatar here is the same `UserAvatar` this group\'s member list '
        'renders, fed from the `Principal` you supply — so a member looks the '
        'same viewed from either end of the relation. Ada and Grace load a '
        'photo URL; Katherine\'s photo is base64 bytes handed over as an '
        '`imageProvider`, never a URL at all; Linus\'s URL is broken, so he '
        'falls back to initials; Margaret has no photo. Which source a photo '
        "comes from is your app's decision — for one behind an authenticated "
        "endpoint, or one already in your app's cache, pass `avatarHeaders` / "
        '`avatarImageProviderBuilder` and the load is routed through them.',
        icon: Icons.account_circle_outlined,
      ),
    );
  }
}

/// A low-emphasis footer note explaining that some behavior is the host app's
/// decision rather than a widget feature — shared by every tab's footer.
class _FooterNote extends StatelessWidget {
  const _FooterNote(this.message, {this.icon = Icons.lock_outline});

  final String message;

  /// Glyph fronting the note. Defaults to the lock the locking notes use.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

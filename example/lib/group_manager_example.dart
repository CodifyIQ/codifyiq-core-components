import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';

/// Demo for [GroupManagerController], [GroupManagerView], and
/// [GroupAssignmentField].
///
/// The first tab manages the group catalog (create / edit / delete). The
/// second assigns one or more of those groups to a handful of demo users via
/// removable chips and a searchable picker. The third shows the same field
/// attaching groups to a *non-user* target — folders — where the choices are
/// scoped to only the groups the signed-in user belongs to. All three tabs are
/// driven by a single UI-only controller — edits on one are reflected on the
/// others.
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
      'ada': {'admins', 'editors'},
      'grace': {'editors'},
    },
  );

  static const List<({String id, String name})> _users = [
    (id: 'ada', name: 'Ada Lovelace'),
    (id: 'grace', name: 'Grace Hopper'),
    (id: 'linus', name: 'Linus Torvalds'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Group Manager Example'),
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
            GroupManagerView(controller: _controller),
            _MembersTab(controller: _controller, users: _users),
            _FoldersTab(controller: _controller, currentUserId: 'ada'),
          ],
        ),
      ),
    );
  }
}

class _MembersTab extends StatefulWidget {
  const _MembersTab({required this.controller, required this.users});

  final GroupManagerController controller;
  final List<({String id, String name})> users;

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final users = q.isEmpty
        ? widget.users
        : widget.users.where((u) => u.name.toLowerCase().contains(q)).toList();

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
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
                          itemCount: users.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: GroupAssignmentField(
                                  label: user.name,
                                  groups: widget.controller.groups,
                                  selected: widget.controller.groupsFor(
                                    user.id,
                                  ),
                                  onChanged: (ids) => widget.controller
                                      .setAssignments(user.id, ids),
                                  // Editing a person's memberships reads better
                                  // with a "manage user" glyph than a pencil.
                                  editIcon: Icons.manage_accounts_outlined,
                                  editLabel: 'Edit groups',
                                  pickerTitle: 'Assign groups to ${user.name}',
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
class _FoldersTab extends StatelessWidget {
  const _FoldersTab({required this.controller, required this.currentUserId});

  final GroupManagerController controller;
  final String currentUserId;

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
    // folder, so an existing share stays visible and removable even if they
    // later leave that group. Without this the assignment would orphan: gone
    // from both the chips and the picker, yet still in the data.
    final offered = <Group>[
      for (final group in controller.groups)
        if (grantableIds.contains(group.id) || shared.contains(group.id)) group,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GroupAssignmentField(
          label: folder.name,
          groups: offered,
          selected: shared,
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
              ],
            ),
          ),
        );
      },
    );
  }
}

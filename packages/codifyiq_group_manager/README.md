# codifyiq_group_manager

[![pub package](https://img.shields.io/pub/v/codifyiq_group_manager.svg)](https://pub.dev/packages/codifyiq_group_manager)

Material 3 widgets for managing **flat authorization groups** and assigning one or more of them
to users. Groups are intentionally simple — no nesting and no separate roles. A principal (a user,
service account, or any subject you authorize) is just assigned one or more groups, and your app
derives whatever permissions it likes from that membership.

This package is **UI-only**: it never talks to a backend. You drive the controller and wire its
mutations to your own persistence layer.

## Installation

```yaml
dependencies:
  codifyiq_group_manager: ^1.0.0
```

## Concepts

| Piece | Role |
|---|---|
| `Group` | Immutable group model (id, name, optional description/color/icon). |
| `GroupColor` | Theme-derived accent role (resolves against `ColorScheme`). |
| `GroupManagerController` | UI-only state container for the catalog and assignments. |
| `GroupManagerScope` | Inherited notifier exposing the controller to a subtree. |
| `GroupManagerView` | Drop-in catalog screen (create / edit / delete + search). |
| `GroupListView` | The catalog list, controller-driven, with edit/delete + filter. |
| `GroupAssignmentField` | Assign groups to any target (user, folder, …) — chips + searchable add picker. |
| `GroupPicker` | Searchable multi-select picker — adaptive bottom sheet / dialog. |
| `GroupEditorDialog` / `GroupChip` / `GroupAvatar` | Composable building blocks. |

## Usage

### Manage the catalog

```dart
final controller = GroupManagerController(
  groups: const [
    Group(id: 'admins', name: 'Administrators', icon: Icons.admin_panel_settings),
    Group(id: 'editors', name: 'Editors'),
  ],
);

// Drop the full management surface into a Scaffold body:
Scaffold(body: GroupManagerView(controller: controller));
```

`GroupManagerView` (and `GroupListView`) handle create, edit, and delete against the controller,
and `GroupManagerView` includes a search field that filters the catalog once it has groups.
Deleting a group cascades — it is also unassigned from every member.

### Group colors follow the theme

A group's accent is a `GroupColor` role (`primary`, `secondary`, `tertiary`, `neutral`) resolved
against the active `ColorScheme` at render time — so it harmonizes with your app and adapts to
light/dark automatically. Leave `Group.color` `null` to auto-assign a stable role per group:

```dart
const Group(id: 'admins', name: 'Administrators', color: GroupColor.primary);
const Group(id: 'editors', name: 'Editors'); // auto-derived, stable per id
```

### Assign groups to a user

`GroupAssignmentField` is value-driven, so wire it to the controller from your form:

```dart
ListenableBuilder(
  listenable: controller,
  builder: (context, _) => GroupAssignmentField(
    label: 'Groups',
    groups: controller.groups,
    selected: controller.groupsFor(userId),
    onChanged: (ids) => controller.setAssignments(userId, ids),
  ),
);
```

### Assign groups to any object (folder, document, project, …)

The field is target-agnostic, and assignments are keyed by any id you choose — so
the same field attaches groups to a folder just as well as to a user. Key the
assignment by the object's id, and offer a **scoped subset** of groups to limit
choices — for example, only the groups the signed-in user belongs to (what they
are allowed to grant):

```dart
GroupAssignmentField(
  label: folder.name,
  groups: controller.resolvedGroupsFor(currentUserId), // only what I can grant
  selected: controller.groupsFor('folder:${folder.id}'),
  onChanged: (ids) => controller.setAssignments('folder:${folder.id}', ids),
  pickerTitle: 'Share "${folder.name}" with your groups',
);
```

### Ambient access via scope

```dart
GroupManagerScope(
  controller: controller,
  child: MyApp(),
);

// Anywhere below:
GroupManagerScope.of(context).assign(userId, 'admins');
```

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

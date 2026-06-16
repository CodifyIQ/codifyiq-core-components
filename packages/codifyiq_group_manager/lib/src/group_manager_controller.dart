import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'group.dart';

/// State container for authorization groups and their assignment to principals.
///
/// Holds two things:
///
/// 1. A **catalog** of [Group]s, in insertion order.
/// 2. A set of **assignments** mapping each principal id (a user, service
///    account, or any other subject the host app authorizes) to the ids of the
///    groups it belongs to.
///
/// Typical lifecycle:
///
/// 1. Seed the catalog via the constructor or [addGroup].
/// 2. Manage the catalog with [addGroup], [updateGroup], and [removeGroup].
///    Removing a group cascades — it is also stripped from every principal's
///    assignments.
/// 3. Assign membership with [assign], [unassign], or [setAssignments], and
///    read it back with [groupsFor] / [resolvedGroupsFor].
///
/// This controller is **UI-only**: it never talks to a backend. Consumers wire
/// its mutations to their own persistence layer (REST, GraphQL, Firestore,
/// etc.) — typically by calling the controller optimistically and then
/// reconciling, or by mutating it from within a successful response handler.
class GroupManagerController extends ChangeNotifier {
  /// Creates a controller seeded with an optional [groups] catalog and
  /// [assignments].
  ///
  /// [assignments] maps a principal id to the set of group ids it belongs to;
  /// entries referencing unknown groups are tolerated and simply ignored by
  /// [resolvedGroupsFor].
  GroupManagerController({
    List<Group> groups = const <Group>[],
    Map<String, Set<String>> assignments = const <String, Set<String>>{},
  }) {
    for (final group in groups) {
      _groups[group.id] = group;
    }
    assignments.forEach((principalId, groupIds) {
      _assignments[principalId] = <String>{...groupIds};
    });
  }

  // Insertion-ordered map preserves catalog order for stable list rendering.
  final Map<String, Group> _groups = <String, Group>{};
  final Map<String, Set<String>> _assignments = <String, Set<String>>{};

  /// Unmodifiable view of every group in the catalog, in insertion order.
  List<Group> get groups => List<Group>.unmodifiable(_groups.values);

  /// Whether the catalog currently has no groups.
  bool get isEmpty => _groups.isEmpty;

  /// Number of groups in the catalog.
  int get length => _groups.length;

  /// Looks up a group by [id], or returns `null` if absent.
  Group? groupById(String id) => _groups[id];

  /// Adds [group] to the catalog.
  ///
  /// Throws an [ArgumentError] if a group with the same id already exists — use
  /// [updateGroup] to modify an existing group.
  void addGroup(Group group) {
    if (_groups.containsKey(group.id)) {
      throw ArgumentError.value(
        group.id,
        'group.id',
        'A group with this id already exists',
      );
    }
    _groups[group.id] = group;
    notifyListeners();
  }

  /// Replaces the catalog group sharing [group]'s id.
  ///
  /// Throws an [ArgumentError] if no such group exists — use [addGroup] to
  /// create one. Assignments are preserved, since membership keys on the id,
  /// which is unchanged.
  void updateGroup(Group group) {
    if (!_groups.containsKey(group.id)) {
      throw ArgumentError.value(
        group.id,
        'group.id',
        'No group with this id exists',
      );
    }
    _groups[group.id] = group;
    notifyListeners();
  }

  /// Removes the group with [id] from the catalog and from every principal's
  /// assignments.
  ///
  /// Does nothing if no such group exists.
  void removeGroup(String id) {
    if (_groups.remove(id) == null) return;
    // Strip the group from every principal, dropping any principal left with
    // no memberships so empty entries don't accumulate.
    _assignments.removeWhere((_, memberships) {
      memberships.remove(id);
      return memberships.isEmpty;
    });
    notifyListeners();
  }

  /// Returns the ids of the groups assigned to [principalId].
  ///
  /// The returned set is an unmodifiable snapshot; mutate membership through
  /// [assign], [unassign], or [setAssignments].
  Set<String> groupsFor(String principalId) =>
      Set<String>.unmodifiable(_assignments[principalId] ?? const <String>{});

  /// Returns the [Group]s assigned to [principalId], in catalog order.
  ///
  /// Assignment ids that no longer resolve to a catalog group are skipped.
  List<Group> resolvedGroupsFor(String principalId) {
    final ids = _assignments[principalId];
    if (ids == null || ids.isEmpty) return const <Group>[];
    return <Group>[
      for (final group in _groups.values)
        if (ids.contains(group.id)) group,
    ];
  }

  /// Whether [principalId] is currently a member of the group [groupId].
  bool isAssigned(String principalId, String groupId) =>
      _assignments[principalId]?.contains(groupId) ?? false;

  /// Adds [principalId] to the group [groupId].
  ///
  /// Does nothing if the membership already exists. Throws an [ArgumentError] if
  /// [groupId] is not in the catalog, mirroring [addGroup] / [updateGroup] — a
  /// single deliberate assignment to a non-existent group is a programming
  /// error, not a silent no-op. For bulk reconciliation that tolerates unknown
  /// ids, use [setAssignments].
  void assign(String principalId, String groupId) {
    if (!_groups.containsKey(groupId)) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'No group with this id exists',
      );
    }
    final memberships = _assignments.putIfAbsent(principalId, () => <String>{});
    if (memberships.add(groupId)) notifyListeners();
  }

  /// Removes [principalId] from the group [groupId].
  ///
  /// Does nothing if the membership does not exist.
  void unassign(String principalId, String groupId) {
    final memberships = _assignments[principalId];
    if (memberships == null) return;
    if (!memberships.remove(groupId)) return;
    // Drop the principal entirely once its last membership is gone, matching
    // setAssignments — no lingering empty entries.
    if (memberships.isEmpty) _assignments.remove(principalId);
    notifyListeners();
  }

  /// Replaces [principalId]'s entire membership with [groupIds].
  ///
  /// Ids that are not present in the catalog are ignored. Passing an empty set
  /// clears the principal's membership.
  void setAssignments(String principalId, Set<String> groupIds) {
    final next = <String>{
      for (final id in groupIds)
        if (_groups.containsKey(id)) id,
    };
    final current = _assignments[principalId] ?? const <String>{};
    if (setEquals(current, next)) return;
    if (next.isEmpty) {
      _assignments.remove(principalId);
    } else {
      _assignments[principalId] = next;
    }
    notifyListeners();
  }
}

/// Provides an ambient [GroupManagerController] to descendants.
///
/// Wrap a subtree so any widget below can reach the controller without
/// prop-drilling:
///
/// ```dart
/// GroupManagerScope(
///   controller: myController,
///   child: MyApp(),
/// );
///
/// // Anywhere below:
/// GroupManagerScope.of(context).assign(userId, groupId);
/// ```
class GroupManagerScope extends InheritedNotifier<GroupManagerController> {
  /// Creates a scope hosting [controller].
  const GroupManagerScope({
    super.key,
    required GroupManagerController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Returns the nearest enclosing controller.
  ///
  /// By default the calling element is registered as a dependency and rebuilds
  /// whenever the controller fires. Pass `listen: false` to look it up without
  /// subscribing — useful when the caller already wraps its build in a
  /// [ListenableBuilder].
  ///
  /// Throws a [FlutterError] when no scope is found.
  static GroupManagerController of(BuildContext context, {bool listen = true}) {
    final controller = maybeOf(context, listen: listen);
    assert(
      controller != null,
      'No GroupManagerScope found in the widget tree.',
    );
    return controller!;
  }

  /// Like [of] but returns `null` when no scope is present.
  static GroupManagerController? maybeOf(
    BuildContext context, {
    bool listen = true,
  }) {
    if (listen) {
      return context
          .dependOnInheritedWidgetOfExactType<GroupManagerScope>()
          ?.notifier;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<GroupManagerScope>();
    return (element?.widget as GroupManagerScope?)?.notifier;
  }
}

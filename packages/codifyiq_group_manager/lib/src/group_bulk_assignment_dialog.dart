import 'package:flutter/material.dart';

import 'group.dart';
import 'group_picker.dart';

/// Picks the groups to add to, or remove from, many principals at once.
///
/// The host app owns principal selection — this package never models
/// "users" — so both [show] and [showRemoval] take only [principalCount], the
/// number of principals already selected elsewhere (e.g. checked rows in a
/// user table). Neither reads or reconciles any principal's *current*
/// membership; apply the result additively or subtractively yourself,
/// typically via [GroupManagerController.assignMany] or
/// [GroupManagerController.unassignMany]:
///
/// ```dart
/// final toAdd = await GroupBulkAssignmentDialog.show(
///   context,
///   groups: controller.groups,
///   principalCount: selectedUserIds.length,
/// );
/// if (toAdd != null) controller.assignMany(selectedUserIds, toAdd);
///
/// // Elsewhere, scope the offered groups to what's worth removing — e.g. the
/// // union of groups actually held by the selected principals:
/// final toRemove = await GroupBulkAssignmentDialog.showRemoval(
///   context,
///   groups: heldByAnySelectedUser,
///   principalCount: selectedUserIds.length,
///   lockedIds: lockedGroups, // e.g. "Administrators" — never bulk-removable
/// );
/// if (toRemove != null) controller.unassignMany(selectedUserIds, toRemove);
/// ```
///
/// Both are presented with the same adaptive chrome as [GroupPicker] (see
/// [GroupPicker.show]) — a bottom sheet on compact widths, a dialog at 600dp
/// and wider — with title and confirm button wording reframed around the
/// principal count and the add/remove action, rather than the usual
/// single-target wording. [showRemoval] additionally tints the picker with
/// [GroupPicker.destructive], since checking a box there means the opposite
/// of what it means in [show] — "remove this" rather than "keep this".
abstract final class GroupBulkAssignmentDialog {
  /// Shows the picker and resolves with the group ids to add to
  /// [principalCount] principals, or `null` if dismissed without confirming.
  ///
  /// Groups in [lockedIds] appear checked-and-disabled and are always
  /// included in the result — the same semantics as [GroupPicker.lockedIds].
  static Future<Set<String>?> show(
    BuildContext context, {
    required List<Group> groups,
    required int principalCount,
    Set<String> lockedIds = const <String>{},
  }) {
    final target = _targetLabel(principalCount);
    return GroupPicker.show(
      context,
      groups: groups,
      lockedIds: lockedIds,
      title: 'Add groups to $target',
      confirmLabel: 'Add to $target',
    );
  }

  /// Shows the picker and resolves with the group ids to remove from
  /// [principalCount] principals, or `null` if dismissed without confirming.
  ///
  /// Pass only the groups worth offering — typically the union of groups
  /// actually held by the selected principals, since offering the full
  /// catalog would let someone "remove" a group nobody in the selection has.
  ///
  /// [lockedIds] groups are dropped from the offered list entirely, rather
  /// than shown checked-and-disabled like [GroupPicker.lockedIds] normally
  /// does — that mechanism forces a locked group into the *resolved*
  /// selection, which here means "always remove it", the opposite of what
  /// locking is for. Excluding them is the only way to keep a locked group
  /// truly unremovable through this dialog.
  static Future<Set<String>?> showRemoval(
    BuildContext context, {
    required List<Group> groups,
    required int principalCount,
    Set<String> lockedIds = const <String>{},
  }) {
    final target = _targetLabel(principalCount);
    final removable = [
      for (final group in groups)
        if (!lockedIds.contains(group.id)) group,
    ];
    return GroupPicker.show(
      context,
      groups: removable,
      title: 'Remove groups from $target',
      confirmLabel: 'Remove from $target',
      destructive: true,
    );
  }

  static String _targetLabel(int principalCount) {
    assert(principalCount > 0, 'principalCount must be positive');
    return principalCount == 1 ? '1 user' : '$principalCount users';
  }
}

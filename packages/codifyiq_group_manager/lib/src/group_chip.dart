import 'package:flutter/material.dart';

import 'chip_role_label.dart';
import 'group.dart';
import 'group_avatar.dart';

/// A Material 3 chip representing a single [Group].
///
/// When [locked] is true the chip is permanent: it shows a trailing lock glyph
/// (tooltip: "Required — can't be removed") in place of any delete affordance,
/// and [onDeleted] is ignored. Otherwise, when [onDeleted] is provided the chip
/// renders as a removable [InputChip] (with a trailing delete affordance) — the
/// shape used inside [GroupAssignmentField] for an assigned group. With neither,
/// it renders as a static, read-only chip suitable for compact membership
/// summaries.
///
/// Set [roleLabel] to show the assignment's role after the name
/// (`name · role`), and [onRolePressed] to make a tap on the chip change that
/// role, cued by a drop-down glyph — the shape the assignment fields use when
/// given roles.
class GroupChip extends StatelessWidget {
  /// Creates a [GroupChip] for [group].
  const GroupChip({
    super.key,
    required this.group,
    this.onDeleted,
    this.onPressed,
    this.locked = false,
    this.roleLabel,
    this.onRolePressed,
  });

  /// The group to display.
  final Group group;

  /// Called when the user removes the chip. When non-null — and the chip is not
  /// [locked] — the chip shows a trailing delete icon.
  final VoidCallback? onDeleted;

  /// Called when the user taps the chip body — unless [onRolePressed] takes
  /// the tap to change the chip's role.
  final VoidCallback? onPressed;

  /// Whether the group is permanently assigned. A locked chip shows a trailing
  /// lock glyph instead of a delete affordance and cannot be removed; both
  /// [onDeleted] and [onPressed] are ignored. The lock cue matches the locked
  /// rows in [GroupPicker] and the catalog [GroupListView].
  final bool locked;

  /// The role this group's assignment carries, shown after the name as
  /// `name · role` in a de-emphasized color. Display only — pair it with
  /// [onRolePressed] to let the user change it. When `null` (the default) the
  /// chip shows the name alone.
  final String? roleLabel;

  /// Called when the user taps the chip to change its role. When non-null and
  /// the chip is not [locked], the label gains a trailing drop-down glyph and
  /// a tap on the chip body (anywhere but the delete icon) calls this *instead
  /// of* [onPressed]: Material chips route every such tap to a single target.
  /// Works with a `null` [roleLabel] too, for a chip that has no role yet.
  /// Ignored on a [locked] chip, whose role is as fixed as its membership.
  final VoidCallback? onRolePressed;

  @override
  Widget build(BuildContext context) {
    final avatar = GroupAvatar(group: group, radius: 12);
    final canChangeRole = !locked && onRolePressed != null;
    final Widget label = roleLabel == null && !canChangeRole
        ? Text(group.name)
        : ChipRoleLabel(
            name: group.name,
            roleLabel: roleLabel,
            canChangeRole: canChangeRole,
          );
    // Material chips route every tap outside the delete icon to one target, so
    // the role menu takes the chip-body tap when the role can change.
    final onBodyPressed = canChangeRole ? onRolePressed : onPressed;

    if (locked) {
      // A trailing lock glyph stands in for the delete affordance, so a
      // permanent group reads as deliberately fixed rather than as a chip that
      // is merely missing its remove button. Material's Chip only renders a
      // deleteIcon alongside an onDeleted handler, so the glyph rides the label
      // to stay non-interactive.
      final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
      return Tooltip(
        message: "Required — can't be removed",
        child: Chip(
          avatar: avatar,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              label,
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, size: 16, color: onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    if (onDeleted != null) {
      return InputChip(
        avatar: avatar,
        label: label,
        onPressed: onBodyPressed,
        onDeleted: onDeleted,
        deleteButtonTooltipMessage: 'Remove ${group.name}',
      );
    }

    return onBodyPressed != null
        ? ActionChip(avatar: avatar, label: label, onPressed: onBodyPressed)
        : Chip(avatar: avatar, label: label);
  }
}

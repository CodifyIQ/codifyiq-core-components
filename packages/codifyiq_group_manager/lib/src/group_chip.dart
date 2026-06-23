import 'package:flutter/material.dart';

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
class GroupChip extends StatelessWidget {
  /// Creates a [GroupChip] for [group].
  const GroupChip({
    super.key,
    required this.group,
    this.onDeleted,
    this.onPressed,
    this.locked = false,
  });

  /// The group to display.
  final Group group;

  /// Called when the user removes the chip. When non-null — and the chip is not
  /// [locked] — the chip shows a trailing delete icon.
  final VoidCallback? onDeleted;

  /// Called when the user taps the chip body.
  final VoidCallback? onPressed;

  /// Whether the group is permanently assigned. A locked chip shows a trailing
  /// lock glyph instead of a delete affordance and cannot be removed; both
  /// [onDeleted] and [onPressed] are ignored. The lock cue matches the locked
  /// rows in [GroupPicker] and the catalog [GroupListView].
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final avatar = GroupAvatar(group: group, radius: 12);
    final label = Text(group.name);

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
        onPressed: onPressed,
        onDeleted: onDeleted,
        deleteButtonTooltipMessage: 'Remove ${group.name}',
      );
    }

    return onPressed != null
        ? ActionChip(avatar: avatar, label: label, onPressed: onPressed)
        : Chip(avatar: avatar, label: label);
  }
}

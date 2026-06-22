import 'package:flutter/material.dart';

import 'group.dart';
import 'group_avatar.dart';

/// A Material 3 chip representing a single [Group].
///
/// When [onDeleted] is provided the chip renders as a removable
/// [InputChip] (with a trailing delete affordance) — the shape used inside
/// [GroupAssignmentField] for an assigned group. Otherwise it renders as a
/// static, read-only chip suitable for compact membership summaries.
class GroupChip extends StatelessWidget {
  /// Creates a [GroupChip] for [group].
  const GroupChip({
    super.key,
    required this.group,
    this.onDeleted,
    this.onPressed,
  });

  /// The group to display.
  final Group group;

  /// Called when the user removes the chip. When non-null the chip shows a
  /// trailing delete icon.
  final VoidCallback? onDeleted;

  /// Called when the user taps the chip body.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final avatar = GroupAvatar(group: group, radius: 12);
    final label = Text(group.name);

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

import 'package:flutter/material.dart';

/// The label of a [GroupChip] or [PrincipalChip] that carries a role:
/// `name · role`, with the role de-emphasized in `onSurfaceVariant`.
///
/// Internal: shared by both chips so the two render a role identically. When
/// [canChangeRole] is set the label gains a trailing drop-down glyph and
/// announces itself as "name, role, change role". A `null` [roleLabel] with
/// [canChangeRole] renders `name ▾`: a chip that has no role yet but can be
/// given one.
class ChipRoleLabel extends StatelessWidget {
  /// Creates a [ChipRoleLabel].
  const ChipRoleLabel({
    super.key,
    required this.name,
    this.roleLabel,
    this.canChangeRole = false,
  });

  /// The group's or principal's name.
  final String name;

  /// The role shown after [name], or `null` for a chip with no role yet.
  final String? roleLabel;

  /// Whether tapping the chip changes the role, shown as a drop-down glyph.
  final bool canChangeRole;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final roleStyle = TextStyle(color: onSurfaceVariant);
    final role = roleLabel;
    final spoken = role == null ? name : '$name, $role';

    return Semantics(
      label: canChangeRole ? '$spoken, change role' : spoken,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name),
          if (role != null) ...[
            Text(' · ', style: roleStyle),
            Text(role, style: roleStyle),
          ],
          if (canChangeRole)
            Icon(Icons.arrow_drop_down, size: 18, color: onSurfaceVariant),
        ],
      ),
    );
  }
}

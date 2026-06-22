import 'package:flutter/material.dart';

import 'group.dart';
import 'group_color.dart';

/// A small circular badge representing a [Group].
///
/// Renders the group's [Group.icon] when present, otherwise the first letter of
/// its [Group.name]. The circle is tinted with the group's [GroupColor] role
/// resolved against the current theme — or, when the group has no explicit
/// role, a stable one auto-derived from its id. Foreground contrast comes from
/// the role's matching `on*` token, so it is always correct.
class GroupAvatar extends StatelessWidget {
  /// Creates a [GroupAvatar] for [group].
  const GroupAvatar({super.key, required this.group, this.radius = 20.0});

  /// The group to represent.
  final Group group;

  /// Radius of the circle, in logical pixels.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = group.color ?? GroupColor.auto(group.id);
    final (:background, :foreground) = role.resolve(scheme);

    final icon = group.icon;
    final initial = group.name.trim().isEmpty
        ? '?'
        : group.name.trim().characters.first.toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: icon != null
          ? Icon(icon, size: radius, color: foreground)
          : Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.9,
                fontWeight: FontWeight.bold,
                color: foreground,
              ),
            ),
    );
  }
}

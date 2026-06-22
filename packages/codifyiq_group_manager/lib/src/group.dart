import 'package:flutter/widgets.dart';

import 'group_color.dart';

/// An authorization group that one or more principals (users) can belong to.
///
/// Groups are flat — there is no nesting and no separate notion of roles. A
/// principal is simply assigned one or more groups, and the host application
/// derives whatever permissions it likes from that membership.
///
/// Groups are immutable; produce modified copies with [copyWith]. Equality is
/// by value across every field so that list widgets rebuild only when a group
/// actually changes.
@immutable
class Group {
  /// Creates a [Group].
  ///
  /// [id] must be stable and unique within a catalog — it is what the
  /// controller and assignment APIs key on. [name] is the human-readable
  /// label shown in the UI.
  const Group({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.icon,
  });

  /// Stable, unique identifier used to reference the group in assignments.
  final String id;

  /// Human-readable label shown in lists, chips, and pickers.
  final String name;

  /// Optional secondary line describing the group's purpose.
  final String? description;

  /// Optional theme-derived accent for the group's avatar and chip.
  ///
  /// References a Material 3 container role rather than a fixed color, so the
  /// accent always harmonizes with the app theme and adapts to light/dark.
  /// When `null`, a stable role is auto-derived from [id] (see
  /// [GroupColor.auto]).
  final GroupColor? color;

  /// Optional glyph for the group's avatar and chip. When `null`, widgets
  /// fall back to the first letter of [name].
  final IconData? icon;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass [clearDescription], [clearColor], or [clearIcon] to explicitly reset
  /// those nullable fields back to `null`.
  Group copyWith({
    String? id,
    String? name,
    String? description,
    GroupColor? color,
    IconData? icon,
    bool clearDescription = false,
    bool clearColor = false,
    bool clearIcon = false,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      color: clearColor ? null : (color ?? this.color),
      icon: clearIcon ? null : (icon ?? this.icon),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          color == other.color &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(id, name, description, color, icon);

  @override
  String toString() => 'Group(id: $id, name: $name)';
}

import 'package:flutter/foundation.dart';

/// One role an assignment can carry — e.g. a group that can *view* a folder
/// versus one that can *edit* it, or an *owner* of a group versus a plain
/// *member*.
///
/// Roles qualify an **assignment**, not a [Group] or a [Principal]: the same
/// group can be a viewer on one folder and an editor on another. Pass a list of
/// them to [GroupAssignmentField.roles] or [MemberAssignmentField.roles] to show
/// and change each chip's role.
///
/// Like everything else in this package, a role is opaque: the package renders
/// [label] and [description] and reports [id] back, and the host application
/// decides what the role means and enforces it.
///
/// Roles are immutable. Equality is by value across every field.
@immutable
class AssignmentRole {
  /// Creates an [AssignmentRole].
  ///
  /// [id] must be stable and unique within the role list — it is what
  /// `rolesById`, `defaultRoleId`, and `onRoleChanged` key on. [label] is the
  /// human-readable name shown on the chip and in the role menu.
  const AssignmentRole({
    required this.id,
    required this.label,
    this.description,
  });

  /// Stable, unique identifier reported back through `onRoleChanged`.
  final String id;

  /// Human-readable name shown on the chip and in the role menu, e.g.
  /// "Can edit".
  final String label;

  /// Optional secondary line shown beneath [label] in the role menu, e.g.
  /// "Can change files and share them".
  final String? description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignmentRole &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          description == other.description;

  @override
  int get hashCode => Object.hash(id, label, description);

  @override
  String toString() => 'AssignmentRole(id: $id, label: $label)';
}

import 'package:codifyiq_group_manager/src/assignment_role.dart';
import 'package:material_ui/material_ui.dart';

/// A single-select row of chips that narrows a list to one of [roles].
///
/// Internal: [GroupMembersView] shows one beneath its search field when roles
/// are on. The leading "All members" chip clears the filter, as does tapping
/// the selected role again, so the current filter is always on screen along
/// with the way out of it. Each chip is focusable and announced as selected or
/// not, and a role's description, if any, is its tooltip. Scrolls horizontally
/// when the roles outgrow the width.
class RoleFilterBar extends StatelessWidget {
  /// Creates a [RoleFilterBar].
  const RoleFilterBar({
    super.key,
    required this.roles,
    required this.selectedRoleId,
    required this.onChanged,
  });

  /// The roles offered, in chip order.
  final List<AssignmentRole> roles;

  /// The role the list is narrowed to, or `null` for every member.
  final String? selectedRoleId;

  /// Called with the newly chosen role id, or `null` when the filter clears.
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Filter by role',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All members'),
              selected: selectedRoleId == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final role in roles)
              ChoiceChip(
                label: Text(role.label),
                tooltip: role.description,
                selected: role.id == selectedRoleId,
                onSelected: (selected) => onChanged(selected ? role.id : null),
              ),
          ],
        ),
      ),
    );
  }
}

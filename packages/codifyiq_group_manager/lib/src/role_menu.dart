import 'package:codifyiq_group_manager/src/assignment_role.dart';
import 'package:material_ui/material_ui.dart';

/// Anchors a menu of [roles] to the chip that [builder] returns.
///
/// Internal: [AssignmentField] wraps each chip whose role can change in one of
/// these, and hands the chip a callback that toggles the menu. Built on
/// [MenuAnchor], so the menu is keyboard-reachable and dismisses on Escape or
/// an outside tap.
class RoleMenu extends StatelessWidget {
  /// Creates a [RoleMenu].
  const RoleMenu({
    super.key,
    required this.roles,
    required this.currentRoleId,
    required this.onSelected,
    required this.builder,
  });

  /// The roles offered, in menu order.
  final List<AssignmentRole> roles;

  /// The chip's current role id, shown checked. May match none of [roles].
  final String? currentRoleId;

  /// Called with the picked role's id. Not called when the current role is
  /// picked again.
  final ValueChanged<String> onSelected;

  /// Builds the chip, given the callback that opens or closes the menu.
  final Widget Function(VoidCallback onRolePressed) builder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MenuAnchor(
      menuChildren: [
        for (final role in roles)
          MenuItemButton(
            leadingIcon: role.id == currentRoleId
                ? const Icon(Icons.check)
                : const SizedBox(width: 24),
            onPressed: () {
              if (role.id != currentRoleId) onSelected(role.id);
            },
            child: role.description == null
                ? Text(role.label)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role.label),
                      Text(
                        role.description ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
      ],
      builder: (context, controller, _) => builder(
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

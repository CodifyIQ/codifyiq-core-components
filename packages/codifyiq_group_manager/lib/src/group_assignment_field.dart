import 'package:flutter/material.dart';

import 'group.dart';
import 'group_chip.dart';
import 'group_picker.dart';

/// A form field for assigning one or more groups to a target.
///
/// The target is anything your app authorizes — a user, but equally a folder,
/// document, project, or any other object. The widget is target-agnostic: it
/// only deals in the [groups] it may offer and the [selected] ids; the caller
/// decides what those groups are being attached to.
///
/// Renders the currently selected groups as removable [GroupChip]s, with a
/// stationary "Edit" button in the header that opens a searchable [GroupPicker]
/// of the offered [groups]. The picker both adds and removes membership, so the
/// affordance reads "Edit" rather than "Add", and it stays put in the header so
/// it doesn't drift as chips are added or removed. Removing a chip or confirming
/// the picker reports the new selection through [onChanged].
///
/// Only [selected] ids that are present in [groups] are rendered — the widget
/// has no [Group] data for ids outside the offered set, so it can neither show
/// nor remove them. When you scope [groups] to a subset (e.g. only the signed-in
/// user's own groups), keep it a superset of [selected], or reconcile the
/// selection when the offered set shrinks; otherwise a previously-assigned group
/// that drops out of [groups] becomes an invisible, unremovable assignment.
///
/// This widget is value-driven and stateless with respect to membership — the
/// caller owns [selected] and applies updates in [onChanged]. Wire it to a
/// [GroupManagerController] from the caller, for example to assign groups to a
/// user:
///
/// ```dart
/// ListenableBuilder(
///   listenable: controller,
///   builder: (context, _) => GroupAssignmentField(
///     groups: controller.groups,
///     selected: controller.groupsFor(userId),
///     onChanged: (ids) => controller.setAssignments(userId, ids),
///   ),
/// );
/// ```
///
/// To attach groups to some other object — say, share a folder with only the
/// groups the signed-in user belongs to — offer that scoped subset and key the
/// assignment by the object's id:
///
/// ```dart
/// GroupAssignmentField(
///   groups: controller.resolvedGroupsFor(currentUserId), // only what I can grant
///   selected: controller.groupsFor('folder:$folderId'),
///   onChanged: (ids) => controller.setAssignments('folder:$folderId', ids),
/// );
/// ```
class GroupAssignmentField extends StatelessWidget {
  /// Creates a [GroupAssignmentField].
  const GroupAssignmentField({
    super.key,
    required this.groups,
    required this.selected,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.editLabel = 'Edit groups',
    this.editIcon = Icons.group_add_outlined,
    this.pickerTitle = 'Assign groups',
    this.emptyHint = 'No groups assigned',
  });

  /// The groups that may be assigned to the target. Pass the full catalog, or a
  /// scoped subset (e.g. only the signed-in user's own groups) to limit choices.
  final List<Group> groups;

  /// Ids of the groups currently assigned to the target.
  final Set<String> selected;

  /// Called with the updated id set whenever the assignment changes.
  final ValueChanged<Set<String>> onChanged;

  /// Optional label rendered above the chips.
  final String? label;

  /// Whether the field is interactive. When `false`, chips are read-only and
  /// the "Edit" affordance is hidden.
  final bool enabled;

  /// Tooltip for the header button that opens the picker. The picker both adds
  /// and removes membership, so this defaults to "Edit groups" rather than
  /// "Add" — pairing with the group-add [editIcon] without implying add-only.
  final String editLabel;

  /// Icon for the header button that opens the picker. Defaults to a group-add
  /// glyph; pass a more specific domain icon — e.g. a "manage user" glyph when
  /// assigning to a person, or an authorization glyph when granting access.
  final IconData editIcon;

  /// Title shown on the picker sheet.
  final String pickerTitle;

  /// Hint shown in place of the chips when nothing is assigned. When [enabled],
  /// the header's edit button remains available to add the first group.
  final String emptyHint;

  List<Group> get _selectedGroups => <Group>[
    for (final group in groups)
      if (selected.contains(group.id)) group,
  ];

  Future<void> _openPicker(BuildContext context) async {
    final result = await GroupPicker.show(
      context,
      groups: groups,
      initiallySelected: selected,
      title: pickerTitle,
    );
    if (result != null) onChanged(result);
  }

  void _remove(String id) {
    onChanged(<String>{...selected}..remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedGroups = _selectedGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The label and edit trigger share a fixed header row, so the trigger
        // stays anchored instead of drifting to the end of the chip flow as
        // membership changes.
        if (label != null || enabled) ...[
          Row(
            children: [
              if (label != null)
                Expanded(
                  child: Text(
                    label!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (enabled)
                IconButton(
                  icon: Icon(editIcon),
                  tooltip: editLabel,
                  onPressed: () => _openPicker(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (selectedGroups.isEmpty)
          Text(
            emptyHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final group in selectedGroups)
                GroupChip(
                  group: group,
                  onDeleted: enabled ? () => _remove(group.id) : null,
                ),
            ],
          ),
      ],
    );
  }
}

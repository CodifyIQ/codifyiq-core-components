import 'package:flutter/material.dart';

import 'assignment_field.dart';
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
/// stationary "Edit" button that opens a searchable [GroupPicker] of the
/// offered [groups]. The picker both adds and removes membership, so the
/// affordance reads "Edit" rather than "Add". Removing a chip or confirming
/// the picker reports the new selection through [onChanged].
///
/// [MemberAssignmentField] is the mirror image, editing one group's membership
/// rather than one target's groups. The two are interchangeable views of the
/// same assignment data — edit either and the other reflects it.
///
/// Groups whose ids are in [lockedIds] always appear as non-removable chips
/// bearing a trailing lock glyph in place of the delete icon — even when they
/// are absent from [selected] — and are shown checked-and-disabled in the
/// picker. Every selection this field reports
/// through [onChanged], whether from the picker or from removing another chip,
/// includes [lockedIds], so a locked group can never be dropped. The field does
/// not mutate the caller-owned [selected]; if you persist that value, seed it
/// with the locked ids (or apply each [onChanged] update) to keep it in sync.
///
/// Only [selected] ids that are present in [groups] are rendered — the widget
/// has no [Group] data for ids outside the offered set, so it can neither show
/// nor remove them. When you scope [groups] to a subset (e.g. only the signed-in
/// user's own groups), keep it a superset of [selected], or reconcile the
/// selection when the offered set shrinks; otherwise a previously-assigned group
/// that drops out of [groups] becomes an invisible, unremovable assignment.
///
/// By default the label and edit button sit in their own header row, with
/// chips wrapping onto as many lines below as membership needs — good for a
/// single target on a form. Pass [maxVisibleChips] to cap how many of those
/// chips render before collapsing the rest behind a trailing "+N more" chip —
/// handy for a dense list of many targets (e.g. a bulk member list) where
/// showing every membership in full would make rows uneven and hard to scan.
///
/// For a grid-like list of many targets, set [singleLine] instead: the label,
/// chips, and edit button all share one row, and as many chips as fit the
/// available width are shown (further capped by [maxVisibleChips] if also
/// set), with the rest behind "+N more". The row always keeps room for the
/// "+N more" chip itself — an overlong [label] ellipsizes rather than
/// crowding it out too, though it's free to crowd out every *real* chip, down
/// to a row that's just the label and "+N more". Tapping "+N more" expands:
/// in the default stacked mode the chips simply wrap onto more lines, and in
/// [singleLine] mode the fitted row stays put while the overflow groups
/// appear in a second row below it — either way with a trailing "Show less"
/// chip to collapse again, and neither disturbing the chips already shown. The cap
/// only affects which chips are drawn — a group hidden behind "+N more" is
/// still assigned, still counted, and still shown (as locked or removable)
/// the moment the row expands.
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
    this.lockedIds = const <String>{},
    this.label,
    this.enabled = true,
    this.editLabel = 'Edit groups',
    this.editIcon = Icons.group_add_outlined,
    this.pickerTitle = 'Assign groups',
    this.emptyHint = 'No groups assigned',
    this.maxVisibleChips,
    this.singleLine = false,
  }) : assert(
         maxVisibleChips == null || maxVisibleChips > 0,
         'maxVisibleChips must be positive',
       );

  /// The groups that may be assigned to the target. Pass the full catalog, or a
  /// scoped subset (e.g. only the signed-in user's own groups) to limit choices.
  final List<Group> groups;

  /// Ids of the groups currently assigned to the target.
  final Set<String> selected;

  /// Called with the updated id set whenever the assignment changes.
  final ValueChanged<Set<String>> onChanged;

  /// Ids of groups that cannot be removed. These appear as non-removable chips
  /// and are checked-but-disabled in the picker.
  final Set<String> lockedIds;

  /// Optional label. Rendered above the chips by default, or inline to their
  /// left when [singleLine] is set.
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

  /// Caps how many chips render before the rest collapse behind a "+N more"
  /// chip. `null` (the default) shows every chip that otherwise fits — in
  /// [singleLine] mode that means "as many as the available width allows";
  /// in the default stacked mode it means "all of them". See the class doc
  /// for details.
  final int? maxVisibleChips;

  /// Lays the label, chips, and edit button out on a single row instead of a
  /// label row followed by a wrapped chip row — a denser, grid-like shape
  /// suited to a list of many targets. As many chips as fit the row's
  /// available width are shown; the rest collapse behind "+N more". See the
  /// class doc for details.
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final group in groups) group.id: group};
    return AssignmentField(
      entries: [for (final group in groups) (id: group.id, label: group.name)],
      selected: selected,
      onChanged: onChanged,
      lockedIds: lockedIds,
      chipBuilder: (id, {required locked, onDeleted}) => GroupChip(
        // Only ids drawn from `entries` reach the builder, so the lookup
        // always resolves.
        group: byId[id]!,
        locked: locked,
        onDeleted: onDeleted,
      ),
      openPicker: (context) => GroupPicker.show(
        context,
        groups: groups,
        initiallySelected: selected,
        lockedIds: lockedIds,
        title: pickerTitle,
      ),
      label: label,
      enabled: enabled,
      editLabel: editLabel,
      editIcon: editIcon,
      emptyHint: emptyHint,
      maxVisibleChips: maxVisibleChips,
      singleLine: singleLine,
    );
  }
}

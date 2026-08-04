import 'package:flutter/material.dart';

import 'assignment_field.dart';
import 'member_picker.dart';
import 'principal.dart';
import 'principal_avatar.dart';
import 'principal_chip.dart';

/// A form field for adding one or more members to a single group.
///
/// The mirror image of [GroupAssignmentField]: same chips-plus-"Edit" shape,
/// same overflow and locking behavior, same value-driven contract — pointed the
/// other way round the assignment. Where [GroupAssignmentField] edits one
/// target's groups, this edits one group's members. Both read and write the
/// same underlying assignment data, so a change made through either is
/// immediately visible in the other.
///
/// Renders the current members as removable [PrincipalChip]s, with a stationary
/// "Edit" button that opens a searchable [MemberPicker] over the offered
/// [roster]. The picker both adds and removes members, so the affordance reads
/// "Edit" rather than "Add". Removing a chip or confirming the picker reports
/// the new membership through [onChanged].
///
/// Principals whose ids are in [lockedIds] always appear as non-removable chips
/// bearing a trailing lock glyph — even when they are absent from [selected] —
/// and are shown checked-and-disabled in the picker. Every membership this
/// field reports through [onChanged] includes [lockedIds], so a locked member
/// can never be dropped. Use it for a membership your app guarantees, e.g.
/// keeping the group's owner in it.
///
/// Only [selected] ids present in [roster] are rendered — the widget has no
/// [Principal] data for ids outside the offered set, so it can neither show nor
/// remove them. Keep [roster] a superset of [selected], or reconcile the
/// membership when the roster shrinks; otherwise an existing member who drops
/// out of the roster becomes an invisible, unremovable assignment. This matters
/// more here than on the group side: the controller stores ids only, so it can
/// never tell you about a member missing from the roster you supplied.
///
/// Layout options match [GroupAssignmentField] exactly — a stacked label row
/// with wrapping chips by default, [maxVisibleChips] to cap them behind a
/// "+N more" chip, and [singleLine] for a dense, grid-like list of many groups.
///
/// Wire it to a [GroupManagerController] from the caller:
///
/// ```dart
/// ListenableBuilder(
///   listenable: controller,
///   builder: (context, _) => MemberAssignmentField(
///     label: group.name,
///     roster: allUsers,
///     selected: controller.membersOf(group.id),
///     onChanged: (ids) => controller.setMembers(group.id, ids),
///   ),
/// );
/// ```
class MemberAssignmentField extends StatelessWidget {
  /// Creates a [MemberAssignmentField].
  const MemberAssignmentField({
    super.key,
    required this.roster,
    required this.selected,
    required this.onChanged,
    this.lockedIds = const <String>{},
    this.label,
    this.enabled = true,
    this.editLabel = 'Edit members',
    this.editIcon = Icons.person_add_alt_outlined,
    this.pickerTitle = 'Add members',
    this.emptyHint = 'No members yet',
    this.maxVisibleChips,
    this.singleLine = false,
    this.avatarHeaders,
    this.avatarImageProviderBuilder,
  }) : assert(
         maxVisibleChips == null || maxVisibleChips > 0,
         'maxVisibleChips must be positive',
       );

  /// The principals that may be members. Pass the full roster, or a scoped
  /// subset (e.g. only the principals the signed-in user administers) to limit
  /// choices.
  final List<Principal> roster;

  /// Ids of the principals currently in the group.
  final Set<String> selected;

  /// Called with the updated id set whenever the membership changes.
  final ValueChanged<Set<String>> onChanged;

  /// Ids of members that cannot be removed. These appear as non-removable chips
  /// and are checked-but-disabled in the picker.
  final Set<String> lockedIds;

  /// Optional label — typically the group's name. Rendered above the chips by
  /// default, or inline to their left when [singleLine] is set.
  final String? label;

  /// Whether the field is interactive. When `false`, chips are read-only and
  /// the "Edit" affordance is hidden.
  final bool enabled;

  /// Tooltip for the header button that opens the picker. The picker both adds
  /// and removes members, so this defaults to "Edit members" rather than "Add".
  final String editLabel;

  /// Icon for the header button that opens the picker. Defaults to a
  /// person-add glyph — the member-side counterpart of
  /// [GroupAssignmentField]'s group-add default.
  final IconData editIcon;

  /// Title shown on the picker sheet.
  final String pickerTitle;

  /// Hint shown in place of the chips when the group has no members. When
  /// [enabled], the header's edit button remains available to add the first.
  final String emptyHint;

  /// Caps how many chips render before the rest collapse behind a "+N more"
  /// chip. `null` (the default) shows every chip that otherwise fits. See
  /// [GroupAssignmentField.maxVisibleChips] for the full behavior.
  final int? maxVisibleChips;

  /// Lays the label, chips, and edit button out on a single row instead of a
  /// label row followed by a wrapped chip row. See
  /// [GroupAssignmentField.singleLine] for the full behavior.
  final bool singleLine;

  /// HTTP headers forwarded to each member avatar's image provider, in the
  /// chips and in the picker — see [PrincipalAvatar.headers].
  final Map<String, String>? avatarHeaders;

  /// Builds the [ImageProvider] for each member avatar's photo, in the chips
  /// and in the picker — see [PrincipalAvatar.imageProviderBuilder].
  final PrincipalAvatarImageProviderBuilder? avatarImageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final principal in roster) principal.id: principal};
    return AssignmentField(
      entries: [
        for (final principal in roster)
          (id: principal.id, label: principal.name),
      ],
      selected: selected,
      onChanged: onChanged,
      lockedIds: lockedIds,
      chipBuilder: (id, {required locked, onDeleted}) => PrincipalChip(
        // Only ids drawn from `entries` reach the builder, so the lookup
        // always resolves.
        principal: byId[id]!,
        locked: locked,
        onDeleted: onDeleted,
        headers: avatarHeaders,
        imageProviderBuilder: avatarImageProviderBuilder,
      ),
      openPicker: (context) => MemberPicker.show(
        context,
        roster: roster,
        initiallySelected: selected,
        lockedIds: lockedIds,
        title: pickerTitle,
        avatarHeaders: avatarHeaders,
        avatarImageProviderBuilder: avatarImageProviderBuilder,
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

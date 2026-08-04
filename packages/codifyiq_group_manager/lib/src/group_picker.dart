import 'package:flutter/material.dart';

import 'group.dart';
import 'group_avatar.dart';
import 'selection_picker.dart';

/// A searchable, multi-select picker for choosing groups.
///
/// Presentational and value-driven: it takes the full [groups] catalog and the
/// [initiallySelected] ids, and resolves with the updated selection when the
/// user confirms — or `null` if they dismiss it. It performs no persistence.
///
/// Groups whose ids are in [lockedIds] appear checked and disabled, with a lock
/// glyph beside the name (tooltip: "Required — can't be removed") — the user
/// cannot uncheck them. They are always included in the resolved selection.
///
/// [show] presents the picker **adaptively**, following Material 3's
/// large-screen guidance: a modal bottom sheet on compact widths (the M3 mobile
/// pattern for a long, icon-and-description list) and a centered dialog at
/// `600dp` and wider, where a full-width bottom sheet anchored far from its
/// trigger reads awkwardly. The widget body is identical in both — only the
/// surrounding surface differs.
///
/// Used by [GroupAssignmentField] for its "Edit" affordance, but also usable on
/// its own. [MemberPicker] is its mirror image, choosing members for a group
/// rather than groups for a member.
class GroupPicker extends StatelessWidget {
  /// Creates a [GroupPicker].
  const GroupPicker({
    super.key,
    required this.groups,
    this.initiallySelected = const <String>{},
    this.lockedIds = const <String>{},
    this.title = 'Select groups',
    this.confirmLabel,
    this.destructive = false,
  });

  /// Every group the user may choose from.
  final List<Group> groups;

  /// Ids selected when the picker opens.
  final Set<String> initiallySelected;

  /// Ids that are always checked and cannot be unchecked.
  final Set<String> lockedIds;

  /// Heading shown at the top of the picker.
  final String title;

  /// Overrides the confirm button's default "Done (n)" label, where `n` is
  /// the selected count. Useful when the picker is framing a different action
  /// than "select these groups" — e.g. [GroupBulkAssignmentDialog] uses this
  /// to read "Add to 12 users" instead.
  final String? confirmLabel;

  /// Tints the checkboxes and confirm button with the error color instead of
  /// the usual primary/secondary role.
  ///
  /// Checking a box here normally means "select this group" — read as
  /// affirmative in every other use of this picker. Set this when checking a
  /// box instead means the opposite, e.g. "mark this group for removal" (see
  /// [GroupBulkAssignmentDialog.showRemoval]), so the reversed meaning has a
  /// visual cue beyond the title and button text.
  final bool destructive;

  /// Shows the picker adaptively and resolves with the chosen ids, or `null` if
  /// dismissed.
  ///
  /// Presents a modal bottom sheet on compact widths and a dialog at 600dp and
  /// wider.
  static Future<Set<String>?> show(
    BuildContext context, {
    required List<Group> groups,
    Set<String> initiallySelected = const <String>{},
    Set<String> lockedIds = const <String>{},
    String title = 'Select groups',
    String? confirmLabel,
    bool destructive = false,
  }) {
    return SelectionPicker.showAdaptive(
      context,
      picker: GroupPicker(
        groups: groups,
        initiallySelected: initiallySelected,
        lockedIds: lockedIds,
        title: title,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPicker(
      entries: [
        for (final group in groups)
          (
            id: group.id,
            title: group.name,
            subtitle: group.description,
            avatar: GroupAvatar(group: group),
          ),
      ],
      searchHint: 'Search groups',
      noMatchesLabel: (query) => 'No groups match "$query".',
      initiallySelected: initiallySelected,
      lockedIds: lockedIds,
      title: title,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
  }
}

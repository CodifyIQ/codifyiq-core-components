import 'package:flutter/material.dart';

import 'principal.dart';
import 'principal_avatar.dart';
import 'selection_picker.dart';

/// A searchable, multi-select picker for choosing the members of a group.
///
/// The mirror image of [GroupPicker]: same behavior, same adaptive chrome (a
/// modal bottom sheet on compact widths, a centered dialog at `600dp` and
/// wider), pointed the other way round the assignment — it picks principals for
/// one group rather than groups for one principal.
///
/// Presentational and value-driven: it takes the [roster] of principals that
/// may be members and the [initiallySelected] ids, and resolves with the
/// updated membership when the user confirms — or `null` if they dismiss it. It
/// performs no persistence.
///
/// Principals whose ids are in [lockedIds] appear checked and disabled, with a
/// lock glyph beside the name (tooltip: "Required — can't be removed") — the
/// user cannot uncheck them, and they are always included in the resolved
/// selection. Use it for a membership your app guarantees, e.g. keeping the
/// group's owner in it.
///
/// The [roster] is caller-owned, exactly like [GroupPicker]'s catalog. The
/// controller stores only ids, so it cannot enumerate principals who are not
/// yet members of anything — pass everyone who *could* be a member, not just
/// those who already are:
///
/// ```dart
/// final members = await MemberPicker.show(
///   context,
///   roster: allUsers, // every principal that may be added
///   initiallySelected: controller.membersOf(group.id),
///   title: 'Members of ${group.name}',
/// );
/// if (members != null) controller.setMembers(group.id, members);
/// ```
class MemberPicker extends StatelessWidget {
  /// Creates a [MemberPicker].
  const MemberPicker({
    super.key,
    required this.roster,
    this.initiallySelected = const <String>{},
    this.lockedIds = const <String>{},
    this.title = 'Select members',
    this.confirmLabel,
    this.destructive = false,
    this.avatarHeaders,
    this.avatarImageProviderBuilder,
  });

  /// Every principal the user may choose from. Pass the full roster, or a
  /// scoped subset (e.g. only the principals the signed-in user administers).
  final List<Principal> roster;

  /// Ids selected when the picker opens — typically the group's current members.
  final Set<String> initiallySelected;

  /// Ids that are always checked and cannot be unchecked.
  final Set<String> lockedIds;

  /// Heading shown at the top of the picker.
  final String title;

  /// Overrides the confirm button's default "Done (n)" label, where `n` is the
  /// selected count.
  final String? confirmLabel;

  /// Tints the checkboxes and confirm button with the error color instead of
  /// the usual primary/secondary role.
  ///
  /// Checking a box here normally means "this principal is a member". Set this
  /// when checking a box instead means the opposite — "mark this member for
  /// removal" — so the reversed meaning has a visual cue beyond the title and
  /// button text. Mirrors [GroupPicker.destructive].
  final bool destructive;

  /// HTTP headers forwarded to each member avatar's image provider — see
  /// [PrincipalAvatar.headers].
  final Map<String, String>? avatarHeaders;

  /// Builds the [ImageProvider] for each member avatar's photo — see
  /// [PrincipalAvatar.imageProviderBuilder].
  final PrincipalAvatarImageProviderBuilder? avatarImageProviderBuilder;

  /// Shows the picker adaptively and resolves with the chosen ids, or `null` if
  /// dismissed.
  ///
  /// Presents a modal bottom sheet on compact widths and a dialog at 600dp and
  /// wider.
  static Future<Set<String>?> show(
    BuildContext context, {
    required List<Principal> roster,
    Set<String> initiallySelected = const <String>{},
    Set<String> lockedIds = const <String>{},
    String title = 'Select members',
    String? confirmLabel,
    bool destructive = false,
    Map<String, String>? avatarHeaders,
    PrincipalAvatarImageProviderBuilder? avatarImageProviderBuilder,
  }) {
    return SelectionPicker.showAdaptive(
      context,
      picker: MemberPicker(
        roster: roster,
        initiallySelected: initiallySelected,
        lockedIds: lockedIds,
        title: title,
        confirmLabel: confirmLabel,
        destructive: destructive,
        avatarHeaders: avatarHeaders,
        avatarImageProviderBuilder: avatarImageProviderBuilder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPicker(
      entries: [
        for (final principal in roster)
          (
            id: principal.id,
            title: principal.name,
            subtitle: principal.description,
            // The avatar labels itself with the member's name for standalone
            // use; the row's own title already reads it out, so it is excluded
            // here to keep each picker row a single announcement.
            avatar: ExcludeSemantics(
              child: PrincipalAvatar(
                principal: principal,
                headers: avatarHeaders,
                imageProviderBuilder: avatarImageProviderBuilder,
              ),
            ),
          ),
      ],
      searchHint: 'Search members',
      noMatchesLabel: (query) => 'No members match "$query".',
      initiallySelected: initiallySelected,
      lockedIds: lockedIds,
      title: title,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
  }
}

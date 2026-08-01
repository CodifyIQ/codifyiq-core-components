import 'package:flutter/material.dart';

import 'principal.dart';
import 'principal_avatar.dart';

/// A Material 3 chip representing a single [Principal].
///
/// The member-side mirror of [GroupChip], with identical semantics. When
/// [locked] is true the chip is permanent: it shows a trailing lock glyph
/// (tooltip: "Required — can't be removed") in place of any delete affordance,
/// and [onDeleted] is ignored. Otherwise, when [onDeleted] is provided the chip
/// renders as a removable [InputChip] — the shape used inside
/// [MemberAssignmentField] for an assigned member. With neither, it renders as a
/// static, read-only chip suitable for compact membership summaries.
class PrincipalChip extends StatelessWidget {
  /// Creates a [PrincipalChip] for [principal].
  const PrincipalChip({
    super.key,
    required this.principal,
    this.onDeleted,
    this.onPressed,
    this.locked = false,
    this.headers,
    this.imageProviderBuilder,
  });

  /// The principal to display.
  final Principal principal;

  /// Called when the user removes the chip. When non-null — and the chip is not
  /// [locked] — the chip shows a trailing delete icon.
  final VoidCallback? onDeleted;

  /// Called when the user taps the chip body.
  final VoidCallback? onPressed;

  /// Whether the principal is a permanent member. A locked chip shows a
  /// trailing lock glyph instead of a delete affordance and cannot be removed;
  /// both [onDeleted] and [onPressed] are ignored. The lock cue matches the
  /// locked rows in [MemberPicker] and the locked chips in [GroupChip].
  final bool locked;

  /// HTTP headers forwarded to the avatar's image provider — see
  /// [PrincipalAvatar.headers].
  final Map<String, String>? headers;

  /// Builds the [ImageProvider] for the avatar photo — see
  /// [PrincipalAvatar.imageProviderBuilder].
  final PrincipalAvatarImageProviderBuilder? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    // The avatar labels itself with the member's name for standalone use, but
    // the chip's own label already reads it out — excluded here so the chip
    // announces the name once.
    final avatar = ExcludeSemantics(
      child: PrincipalAvatar(
        principal: principal,
        radius: 12,
        headers: headers,
        imageProviderBuilder: imageProviderBuilder,
      ),
    );
    final label = Text(principal.name);

    if (locked) {
      // A trailing lock glyph stands in for the delete affordance, so a
      // permanent member reads as deliberately fixed rather than as a chip that
      // is merely missing its remove button. Material's Chip only renders a
      // deleteIcon alongside an onDeleted handler, so the glyph rides the label
      // to stay non-interactive.
      final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
      return Tooltip(
        message: "Required — can't be removed",
        child: Chip(
          avatar: avatar,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              label,
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, size: 16, color: onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    if (onDeleted != null) {
      return InputChip(
        avatar: avatar,
        label: label,
        onPressed: onPressed,
        onDeleted: onDeleted,
        deleteButtonTooltipMessage: 'Remove ${principal.name}',
      );
    }

    return onPressed != null
        ? ActionChip(avatar: avatar, label: label, onPressed: onPressed)
        : Chip(avatar: avatar, label: label);
  }
}

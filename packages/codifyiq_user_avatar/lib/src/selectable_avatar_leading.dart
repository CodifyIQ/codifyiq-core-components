import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// A list row's leading control: a [UserAvatar] that swaps to a tappable
/// check icon on hover, or permanently once [selected] — the Google
/// Contacts pattern for starting a multi-select without dedicating a whole
/// column to checkboxes up front. The avatar itself is also tappable (not
/// just the hover-revealed icon), since hover has no touch equivalent.
///
/// Sized to a fixed `radius * 2` box so swapping between the avatar and the
/// check icon never shifts the row's layout — pair it with any per-row
/// content (e.g. `codifyiq_group_manager`'s `GroupAssignmentField`) to build
/// a Contacts-style bulk-selectable list:
///
/// ```dart
/// Row(
///   children: [
///     SelectableAvatarLeading(
///       displayName: user.name,
///       selected: selectedIds.contains(user.id),
///       onChanged: (checked) => setState(() {
///         if (checked) {
///           selectedIds.add(user.id);
///         } else {
///           selectedIds.remove(user.id);
///         }
///       }),
///     ),
///     const SizedBox(width: 12),
///     Expanded(child: Text(user.name)),
///   ],
/// )
/// ```
class SelectableAvatarLeading extends StatefulWidget {
  /// Creates a [SelectableAvatarLeading].
  const SelectableAvatarLeading({
    super.key,
    required this.selected,
    required this.onChanged,
    this.displayName,
    this.email,
    this.photoUrl,
    this.imageProvider,
    this.photoBytes,
    this.photoBase64,
    this.radius = 20.0,
  });

  /// Whether this row is currently checked.
  final bool selected;

  /// Called with the new selection state when the avatar/check icon is
  /// tapped.
  final ValueChanged<bool> onChanged;

  /// Forwarded to [UserAvatar.displayName].
  final String? displayName;

  /// Forwarded to [UserAvatar.email].
  final String? email;

  /// Forwarded to [UserAvatar.photoUrl].
  final String? photoUrl;

  /// Forwarded to [UserAvatar.imageProvider].
  final ImageProvider? imageProvider;

  /// Forwarded to [UserAvatar.photoBytes].
  final Uint8List? photoBytes;

  /// Forwarded to [UserAvatar.photoBase64].
  final String? photoBase64;

  /// Radius of the avatar / check icon box.
  final double radius;

  @override
  State<SelectableAvatarLeading> createState() =>
      _SelectableAvatarLeadingState();
}

class _SelectableAvatarLeadingState extends State<SelectableAvatarLeading> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCheck = widget.selected || _hovered;
    final size = widget.radius * 2;
    final name = widget.displayName ?? widget.email;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: size,
        height: size,
        // One InkWell for the whole hover lifecycle — only its child (the
        // avatar vs. a check icon) swaps, never the interactive widget
        // itself. Swapping between two different interactive widgets under a
        // live pointer trips a Flutter web bug on trackpad input:
        // PointerMoveEvent asserts its kind is never
        // PointerDeviceKind.trackpad, but reparenting the hit-tested widget
        // mid-hover can synthesize one that is. Keeping the InkWell's
        // identity stable avoids that.
        child: Semantics(
          button: true,
          checked: widget.selected,
          label: name == null
              ? (widget.selected ? 'Deselect' : 'Select')
              : (widget.selected ? 'Deselect $name' : 'Select $name'),
          child: InkWell(
            onTap: () => widget.onChanged(!widget.selected),
            customBorder: const CircleBorder(),
            child: showCheck
                ? Icon(
                    widget.selected
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    size: size * 0.6,
                    color: widget.selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  )
                // UserAvatar builds its own Semantics node (label, image:
                // true) — excluded here so it doesn't surface as a second,
                // redundant node alongside the outer "Select/Deselect" one.
                : ExcludeSemantics(
                    child: UserAvatar(
                      displayName: widget.displayName,
                      email: widget.email,
                      photoUrl: widget.photoUrl,
                      imageProvider: widget.imageProvider,
                      photoBytes: widget.photoBytes,
                      photoBase64: widget.photoBase64,
                      radius: widget.radius,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

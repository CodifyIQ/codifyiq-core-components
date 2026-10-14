import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart';

/// An action of your own in the image, PDF and video viewers that
/// `ChatAttachments` opens, such as "Copy link" or "Forward".
///
/// It appears in the viewer's overflow menu, after Share and Download.
class ChatAttachmentAction {
  /// Creates a [ChatAttachmentAction].
  ///
  /// [label] is the menu item text, [icon] its icon, and [onSelected] is
  /// called with the message being viewed.
  const ChatAttachmentAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isVisible,
  });

  /// Text shown for the menu item.
  final String label;

  /// Icon shown before [label].
  final IconData icon;

  /// Called with the message being viewed when the action is chosen.
  final void Function(Message message) onSelected;

  /// Decides whether the action is offered for a message, for example only
  /// for PDFs or for the user's own messages. When `null`, it is offered for
  /// every message.
  final bool Function(Message message)? isVisible;
}

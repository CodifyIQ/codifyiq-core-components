import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import 'codify_chat_message.dart';

/// Maps [CodifyChatMessage]s to Flyer Chat's `flutter_chat_types` model.
///
/// This is the only file in the `ai_chat` component that depends on
/// `flutter_chat_types`, keeping the wrapper model and the Flyer types
/// decoupled. It is an internal implementation detail and is not exported
/// from the package.

/// Stable Flyer author for messages sent by the local user.
const types.User userAuthor = types.User(
  id: 'codify-chat-user',
  firstName: 'You',
);

/// Stable Flyer author for messages produced by the AI.
const types.User aiAuthor = types.User(
  id: 'codify-chat-ai',
  firstName: 'Assistant',
);

types.User _authorFor(CodifyChatSender sender) =>
    sender == CodifyChatSender.user ? userAuthor : aiAuthor;

/// Converts a single [CodifyChatMessage] to a Flyer [types.Message].
///
/// - Text messages become [types.TextMessage].
/// - Image messages with a [CodifyChatMessage.sourceUri] become
///   [types.ImageMessage] so Flyer renders the picture inline (and provides
///   tap-to-zoom). Images render from the network or the local file system —
///   no heavy native package is involved.
/// - PDF messages with a [CodifyChatMessage.sourceUri] become
///   [types.FileMessage] so Flyer renders a tappable file row; the tap is
///   forwarded through `AiChatScreen.onMessageTap` for the host to open its
///   PDF viewer. No PDF rendering library is pulled into the chat widget.
/// - Error messages and source-less image/pdf messages become
///   [types.CustomMessage] so `AiChatScreen` renders them through its
///   `customMessageBuilder` (placeholder / error bubbles).
types.Message toFlyerMessage(CodifyChatMessage message) {
  final author = _authorFor(message.sender);
  final createdAt = message.createdAt.millisecondsSinceEpoch;

  switch (message.kind) {
    case CodifyChatMessageKind.text:
      return types.TextMessage(
        author: author,
        id: message.id,
        text: message.text,
        createdAt: createdAt,
        showStatus: message.isFromUser,
        status: message.isSeen ? types.Status.seen : types.Status.sent,
      );
    case CodifyChatMessageKind.image:
      final source = message.sourceUri;
      if (source != null) {
        return types.ImageMessage(
          author: author,
          id: message.id,
          createdAt: createdAt,
          uri: source.toString(),
          // Flyer shows [name] only in its small file-style fallback layout;
          // [size] is unknown for a remote image and is left at 0.
          name: message.text.isEmpty ? 'image' : message.text,
          size: 0,
          showStatus: message.isFromUser,
          status: message.isSeen ? types.Status.seen : types.Status.sent,
        );
      }
      // No source yet — fall back to a placeholder bubble.
      return _placeholderMessage(message, author, createdAt);
    case CodifyChatMessageKind.pdf:
      final source = message.sourceUri;
      if (source != null) {
        return types.FileMessage(
          author: author,
          id: message.id,
          createdAt: createdAt,
          uri: source.toString(),
          name: message.text.isEmpty ? 'document.pdf' : message.text,
          size: message.fileSizeBytes,
          mimeType: 'application/pdf',
          showStatus: message.isFromUser,
          status: message.isSeen ? types.Status.seen : types.Status.sent,
        );
      }
      // No source yet — fall back to a placeholder bubble.
      return _placeholderMessage(message, author, createdAt);
    case CodifyChatMessageKind.error:
      return _placeholderMessage(message, author, createdAt);
  }
}

/// Builds the [types.CustomMessage] that drives a placeholder / error bubble.
///
/// No metadata is attached: `AiChatScreen` resolves the bubble's content kind
/// straight from the [AiChatController] by message id.
types.CustomMessage _placeholderMessage(
  CodifyChatMessage message,
  types.User author,
  int createdAt,
) => types.CustomMessage(author: author, id: message.id, createdAt: createdAt);

/// Converts a timeline (oldest first) into the newest-first list that Flyer
/// Chat's `Chat` widget expects.
List<types.Message> toFlyerMessages(List<CodifyChatMessage> messages) =>
    <types.Message>[
      for (final message in messages.reversed) toFlyerMessage(message),
    ];

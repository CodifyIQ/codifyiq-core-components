import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'codify_chat_message.dart';

/// Maps [CodifyChatMessage]s onto the Flyer Chat (`flutter_chat_core`)
/// [Message] model.
///
/// This is the only file in the `ai_chat` component that depends on
/// `flutter_chat_core`, keeping the CodifyIQ wrapper model decoupled from
/// Flyer. It is an internal implementation detail and is not exported from the
/// package.

/// Stable Flyer user id for messages sent by the local user.
const String userAuthorId = 'codify-chat-user';

/// Stable Flyer user id for messages produced by the AI.
const String aiAuthorId = 'codify-chat-ai';

const Map<String, User> _users = <String, User>{
  userAuthorId: User(id: userAuthorId, name: 'You'),
  aiAuthorId: User(id: aiAuthorId, name: 'Assistant'),
};

/// Resolves the [User] for a Flyer message author id.
///
/// Wired into `Chat.resolveUser`. Returns `null` for unknown ids.
Future<User?> resolveCodifyChatUser(UserID id) async => _users[id];

String _authorIdFor(CodifyChatSender sender) =>
    sender == CodifyChatSender.user ? userAuthorId : aiAuthorId;

/// Converts a [CodifyChatMessage] to a Flyer [Message].
///
/// - Text → [TextMessage] (rendered with Markdown by `FlyerChatTextMessage`).
/// - Image with a [CodifyChatMessage.sourceUri] → [ImageMessage], rendered
///   inline by `FlyerChatImageMessage`.
/// - PDF with a [CodifyChatMessage.sourceUri] → [FileMessage], rendered as a
///   tappable file row by `FlyerChatFileMessage`.
/// - Error messages and source-less image/pdf messages → [CustomMessage], so
///   `AiChatScreen` renders them through its custom builder (placeholder /
///   error bubbles). No PDF/image rendering library is pulled in for those.
Message toFlyerMessage(CodifyChatMessage message) {
  final authorId = _authorIdFor(message.sender);

  switch (message.kind) {
    case CodifyChatMessageKind.text:
      return Message.text(
        id: message.id,
        authorId: authorId,
        text: message.text,
        createdAt: message.createdAt,
        seenAt: message.seenAt,
      );
    case CodifyChatMessageKind.image:
      final source = message.sourceUri;
      if (source != null) {
        return Message.image(
          id: message.id,
          authorId: authorId,
          source: source.toString(),
          text: message.text.isEmpty ? null : message.text,
          createdAt: message.createdAt,
          seenAt: message.seenAt,
        );
      }
      return _customMessage(message, authorId);
    case CodifyChatMessageKind.pdf:
      final source = message.sourceUri;
      if (source != null) {
        return Message.file(
          id: message.id,
          authorId: authorId,
          source: source.toString(),
          name: message.text.isEmpty ? 'document.pdf' : message.text,
          // 0 means "unknown" — passing null hides the size line on the
          // Flyer file row rather than rendering a meaningless "0 B".
          size: message.fileSizeBytes == 0 ? null : message.fileSizeBytes,
          mimeType: 'application/pdf',
          createdAt: message.createdAt,
          seenAt: message.seenAt,
        );
      }
      return _customMessage(message, authorId);
    case CodifyChatMessageKind.error:
      return _customMessage(message, authorId);
  }
}

/// Builds the [CustomMessage] that drives a placeholder / error bubble.
///
/// No metadata is attached: `AiChatScreen` resolves the bubble's content kind
/// straight from the [AiChatController] by message id.
Message _customMessage(CodifyChatMessage message, String authorId) =>
    Message.custom(
      id: message.id,
      authorId: authorId,
      createdAt: message.createdAt,
    );

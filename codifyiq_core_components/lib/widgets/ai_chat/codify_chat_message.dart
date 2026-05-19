import 'package:flutter/foundation.dart';

/// Identifies who authored a [CodifyChatMessage].
enum CodifyChatSender {
  /// A message typed by the local user.
  user,

  /// A message produced by the AI backend.
  ai,
}

/// The kind of content carried by a [CodifyChatMessage].
///
/// MVP renders [text] and [error] fully; [image] and [pdf] are accepted by the
/// model and UI but render only as placeholder bubbles until dedicated viewers
/// are integrated (reached via `AiChatScreen.onMessageTap`).
enum CodifyChatMessageKind {
  /// Plain text content.
  text,

  /// An image response — placeholder only in the MVP.
  image,

  /// A PDF response — placeholder only in the MVP.
  pdf,

  /// An error notice rendered as a distinct bubble.
  error,
}

// Monotonic counter guaranteeing uniqueness when several messages are created
// within the same microsecond.
int _messageSequence = 0;

String _generateMessageId() {
  _messageSequence += 1;
  return 'codify-chat-${DateTime.now().microsecondsSinceEpoch}-$_messageSequence';
}

/// A CodifyIQ chat message — the design-system wrapper model that
/// `flyer_chat_mapper.dart` maps to and from Flyer Chat's message types.
///
/// Messages are immutable; produce modified copies with [copyWith]. Construct
/// them with the named factories ([CodifyChatMessage.user],
/// [CodifyChatMessage.ai], [CodifyChatMessage.pdf], [CodifyChatMessage.image],
/// [CodifyChatMessage.error]) which assign a unique [id] and default the
/// timestamp for you.
@immutable
class CodifyChatMessage {
  /// Creates a [CodifyChatMessage] with every field supplied explicitly.
  ///
  /// Prefer the named factories for the common cases.
  const CodifyChatMessage({
    required this.id,
    required this.sender,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.seenAt,
    this.sourceUri,
    this.fileSizeBytes = 0,
  });

  /// Creates a text message authored by the local user.
  factory CodifyChatMessage.user({
    required String text,
    String? id,
    DateTime? createdAt,
    DateTime? seenAt,
  }) => CodifyChatMessage(
    id: id ?? _generateMessageId(),
    sender: CodifyChatSender.user,
    kind: CodifyChatMessageKind.text,
    text: text,
    createdAt: createdAt ?? DateTime.now(),
    seenAt: seenAt,
  );

  /// Creates a text message authored by the AI.
  factory CodifyChatMessage.ai({
    required String text,
    String? id,
    DateTime? createdAt,
    DateTime? seenAt,
  }) => CodifyChatMessage(
    id: id ?? _generateMessageId(),
    sender: CodifyChatSender.ai,
    kind: CodifyChatMessageKind.text,
    text: text,
    createdAt: createdAt ?? DateTime.now(),
    seenAt: seenAt,
  );

  /// Creates a PDF message.
  ///
  /// When [sourceUri] is set the message renders as a Flyer Chat file row
  /// (document icon, [text] as the file name, and [fileSizeBytes] formatted as
  /// the subtitle); tapping it surfaces through `AiChatScreen.onMessageTap`,
  /// where the host opens its PDF viewer. With no [sourceUri] it falls back to
  /// a placeholder bubble.
  factory CodifyChatMessage.pdf({
    String text = '',
    Uri? sourceUri,
    int fileSizeBytes = 0,
    CodifyChatSender sender = CodifyChatSender.ai,
    String? id,
    DateTime? createdAt,
    DateTime? seenAt,
  }) => CodifyChatMessage(
    id: id ?? _generateMessageId(),
    sender: sender,
    kind: CodifyChatMessageKind.pdf,
    text: text,
    createdAt: createdAt ?? DateTime.now(),
    seenAt: seenAt,
    sourceUri: sourceUri,
    fileSizeBytes: fileSizeBytes,
  );

  /// Creates an image message.
  ///
  /// Renders as a placeholder bubble in the MVP. [text] is an optional caption
  /// and [sourceUri] is reserved for the future image viewer.
  factory CodifyChatMessage.image({
    String text = '',
    Uri? sourceUri,
    CodifyChatSender sender = CodifyChatSender.ai,
    String? id,
    DateTime? createdAt,
    DateTime? seenAt,
  }) => CodifyChatMessage(
    id: id ?? _generateMessageId(),
    sender: sender,
    kind: CodifyChatMessageKind.image,
    text: text,
    createdAt: createdAt ?? DateTime.now(),
    seenAt: seenAt,
    sourceUri: sourceUri,
  );

  /// Creates an error message, rendered as a distinct error bubble.
  factory CodifyChatMessage.error({
    required String text,
    String? id,
    DateTime? createdAt,
  }) => CodifyChatMessage(
    id: id ?? _generateMessageId(),
    sender: CodifyChatSender.ai,
    kind: CodifyChatMessageKind.error,
    text: text,
    createdAt: createdAt ?? DateTime.now(),
  );

  /// Stable identifier, unique within a conversation.
  final String id;

  /// Who authored the message.
  final CodifyChatSender sender;

  /// The kind of content carried by the message.
  final CodifyChatMessageKind kind;

  /// The body for [CodifyChatMessageKind.text] / [CodifyChatMessageKind.error],
  /// or an optional caption/label for [CodifyChatMessageKind.image] /
  /// [CodifyChatMessageKind.pdf].
  final String text;

  /// When the message was created.
  final DateTime createdAt;

  /// When the message first became visible to the user, or `null` if it has
  /// not been seen yet. Set automatically by `AiChatController.markSeen`.
  final DateTime? seenAt;

  /// The network or local source of the image/pdf content.
  ///
  /// Image messages render inline when this is set; pdf messages render as a
  /// tappable Flyer Chat file row. `null` falls back to a placeholder bubble.
  final Uri? sourceUri;

  /// Size of the attached file in bytes, shown as the subtitle on pdf/file
  /// messages. `0` when the size is unknown.
  final int fileSizeBytes;

  /// Whether the message has been seen by the user.
  bool get isSeen => seenAt != null;

  /// Whether the message was authored by the local user.
  bool get isFromUser => sender == CodifyChatSender.user;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass [clearSeenAt] or [clearSourceUri] to explicitly reset those nullable
  /// fields back to `null`.
  CodifyChatMessage copyWith({
    String? id,
    CodifyChatSender? sender,
    CodifyChatMessageKind? kind,
    String? text,
    DateTime? createdAt,
    DateTime? seenAt,
    Uri? sourceUri,
    int? fileSizeBytes,
    bool clearSeenAt = false,
    bool clearSourceUri = false,
  }) {
    return CodifyChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      kind: kind ?? this.kind,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      seenAt: clearSeenAt ? null : (seenAt ?? this.seenAt),
      sourceUri: clearSourceUri ? null : (sourceUri ?? this.sourceUri),
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}

/// `Message.metadata` keys that [ChatAttachments] reads by default.
///
/// `flutter_chat_core`'s messages have no field for a thumbnail or, on
/// videos, a length. Put them in the message's metadata under these keys when
/// you create it, and the bubbles show them without any callbacks:
///
/// ```dart
/// Message.image(
///   id: id,
///   authorId: userId,
///   source: fullUrl,
///   width: 4032,
///   height: 3024,
///   metadata: {ChatAttachmentMetadata.thumbnail: thumbnailUrl},
/// );
/// ```
abstract final class ChatAttachmentMetadata {
  /// A small version of an image, or a poster frame of a video: a network URL
  /// or, outside the web, a local file path. Loaded with the message's
  /// headers.
  static const thumbnail = 'thumbnail';

  /// A video's length in whole milliseconds, as an `int`.
  static const durationMs = 'durationMs';
}

/// Text the attachment bubbles show or announce, for localisation.
///
/// Pass one to `ChatAttachments.labels`, or to a bubble directly.
class ChatAttachmentLabels {
  /// Creates a [ChatAttachmentLabels]. Every label defaults to English.
  const ChatAttachmentLabels({
    this.image = 'Image',
    this.video = 'Video',
    this.playVideo = 'Play video',
    this.sending = 'Sending',
    this.notSent = 'Not sent',
    this.play = 'Play',
    this.pause = 'Pause',
    this.retry = 'Retry',
    this.audioError = 'Could not load audio',
  });

  /// Announced for an image without a caption.
  final String image;

  /// Announced for a video that can't be opened.
  final String video;

  /// Announced for a video that opens when tapped.
  final String playVideo;

  /// Announced for the progress indicator of a message that is sending.
  final String sending;

  /// Announced for the mark on a message that failed to send.
  final String notSent;

  /// Tooltip of an audio message's play button.
  final String play;

  /// Tooltip of an audio message's pause button.
  final String pause;

  /// Tooltip of an audio message's retry button.
  final String retry;

  /// Shown when an audio message fails to load.
  final String audioError;
}

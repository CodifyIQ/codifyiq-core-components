import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:material_ui/material_ui.dart';

import 'chat_attachment_labels.dart';
import 'media_bubble.dart';
import 'upload_overlay.dart';

/// A video message bubble: a [VideoThumbnailTile] with an optional poster and
/// duration, shaped from the video's known dimensions, with an optional
/// caption and the message's time and status below it.
///
/// It loads no video. [ChatAttachments] builds one for every video message.
/// Use it directly when you write your own `videoMessageBuilder`.
class ChatVideoAttachment extends StatelessWidget {
  /// Creates a [ChatVideoAttachment].
  ///
  /// [thumbnail] is the poster image and [onTap] opens the video.
  const ChatVideoAttachment({
    super.key,
    required this.isSentByMe,
    this.thumbnail,
    this.duration,
    this.width,
    this.height,
    this.caption,
    this.onTap,
    this.maxWidth = 280,
    this.maxHeight,
    this.borderRadius,
    this.status,
    this.uploadProgress,
    this.time,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
    this.topWidget,
    this.labels = const ChatAttachmentLabels(),
  });

  /// Whether the current user sent the message, which picks the caption's
  /// bubble colours and whether the status is shown.
  final bool isSentByMe;

  /// The poster image. Without one the tile shows a plain background.
  final ImageProvider? thumbnail;

  /// The video's length, shown in the tile's corner when known.
  final Duration? duration;

  /// The video's width in pixels, if known. With [height] it sets the tile's
  /// shape; otherwise the tile is 16:9.
  final double? width;

  /// The video's height in pixels, if known.
  final double? height;

  /// Text shown below the video.
  final String? caption;

  /// Called when the tile is tapped. If `null`, the bubble leaves taps to the
  /// widgets around it, such as `Chat`'s `onMessageTap`.
  final VoidCallback? onTap;

  /// The widest the bubble grows.
  final double maxWidth;

  /// The tallest the tile grows. Defaults to 4/3 of [maxWidth].
  final double? maxHeight;

  /// The bubble's corner radius. Defaults to the `ChatTheme`'s shape.
  final BorderRadiusGeometry? borderRadius;

  /// The message's status. While it is [MessageStatus.sending] the bubble
  /// is dimmed with a progress indicator, and [MessageStatus.error] marks it
  /// as not sent.
  final MessageStatus? status;

  /// The upload's progress from 0 to 1 while [status] is
  /// [MessageStatus.sending]. Without it the indicator spins.
  final Stream<double>? uploadProgress;

  /// When the message was sent, shown below the tile.
  final DateTime? time;

  /// Whether [time] is shown.
  final bool showTime;

  /// Whether [status] is shown next to the time, for the current user's
  /// messages.
  final bool showStatus;

  /// Where the time and status sit below the tile: on a line of their own
  /// at the start or end edge, or with [TimeAndStatusPosition.inline] beside
  /// the caption.
  final TimeAndStatusPosition timeAndStatusPosition;

  /// A widget above the tile, such as the author's name.
  final Widget? topWidget;

  /// Text the bubble announces.
  final ChatAttachmentLabels labels;

  @override
  Widget build(BuildContext context) {
    final w = width ?? 0;
    final h = height ?? 0;
    final aspectRatio = w > 0 && h > 0 ? w / h : 16 / 9;

    return MediaBubble(
      aspectRatio: aspectRatio,
      isSentByMe: isSentByMe,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      borderRadius: borderRadius,
      caption: caption,
      topWidget: topWidget,
      time: time,
      status: status,
      showTime: showTime,
      showStatus: showStatus,
      timeAndStatusPosition: timeAndStatusPosition,
      // Expanded to the bubble's box, so a tall video that hits the height
      // limit fills the full width instead of leaving a band beside it.
      media: Stack(
        fit: StackFit.expand,
        children: [
          VideoThumbnailTile(
            thumbnail: thumbnail,
            duration: duration,
            onTap: onTap,
            aspectRatio: aspectRatio,
            borderRadius: BorderRadius.zero,
            semanticLabel: onTap != null ? labels.playVideo : labels.video,
          ),
          UploadOverlay(
            status: status,
            progress: uploadProgress,
            labels: labels,
          ),
        ],
      ),
    );
  }
}

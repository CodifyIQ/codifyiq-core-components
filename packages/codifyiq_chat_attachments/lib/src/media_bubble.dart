import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart';

import 'chat_style.dart';
import 'time_and_status.dart';

/// The shell shared by image and video bubbles: [media] filling a box of
/// [aspectRatio], no wider than [maxWidth] or taller than [maxHeight], with
/// an optional [topWidget] above it and an optional caption and the time and
/// status below it, laid out as on `flutter_chat_ui`'s text bubbles.
class MediaBubble extends StatelessWidget {
  /// Creates a [MediaBubble].
  const MediaBubble({
    super.key,
    required this.media,
    required this.aspectRatio,
    required this.isSentByMe,
    required this.maxWidth,
    this.maxHeight,
    this.borderRadius,
    this.caption,
    this.topWidget,
    this.time,
    this.status,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
  });

  /// The picture or video tile, sized to fill the box.
  final Widget media;

  /// The box's width divided by its height.
  final double aspectRatio;

  /// Whether the current user sent the message, which picks the bubble's
  /// colours and whether its status is shown.
  final bool isSentByMe;

  /// The widest the bubble grows.
  final double maxWidth;

  /// The tallest [media] grows. Defaults to 4/3 of [maxWidth].
  final double? maxHeight;

  /// The bubble's corner radius. Defaults to the `ChatTheme`'s shape.
  final BorderRadiusGeometry? borderRadius;

  /// Text shown below [media].
  final String? caption;

  /// A widget above [media], such as the author's name.
  final Widget? topWidget;

  /// When the message was sent.
  final DateTime? time;

  /// The message's status.
  final MessageStatus? status;

  /// Whether [time] is shown.
  final bool showTime;

  /// Whether [status] is shown, for the current user's messages.
  final bool showStatus;

  /// Where the time and status sit below [media]: on a line of their own at
  /// the start or end edge, or with [TimeAndStatusPosition.inline] beside
  /// the caption.
  final TimeAndStatusPosition timeAndStatusPosition;

  @override
  Widget build(BuildContext context) {
    final theme = chatThemeOf(context);
    final (background, foreground) = bubbleColors(
      theme,
      isSentByMe: isSentByMe,
    );
    final text = caption;
    final top = topWidget;
    final shownTime = showTime ? time : null;
    final shownStatus = showStatus && isSentByMe ? status : null;
    final timeAndStatus = shownTime != null || shownStatus != null
        ? TimeAndStatus(
            time: shownTime,
            status: shownStatus,
            color: foreground.withValues(alpha: 0.8),
          )
        : null;
    final captionText = text != null && text.isNotEmpty
        ? Text(
            text,
            style: theme.typography.bodyMedium.copyWith(color: foreground),
          )
        : null;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: borderRadius ?? theme.shape,
        child: ColoredBox(
          color: background,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (top != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: top,
                ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxHeight ?? maxWidth * 4 / 3,
                ),
                child: AspectRatio(aspectRatio: aspectRatio, child: media),
              ),
              if (captionText != null || timeAndStatus != null)
                Padding(
                  padding: captionText == null
                      ? const EdgeInsets.fromLTRB(12, 4, 12, 6)
                      : const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: switch ((captionText, timeAndStatus)) {
                    (final caption?, final time?)
                        when timeAndStatusPosition ==
                            TimeAndStatusPosition.inline =>
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        spacing: 8,
                        children: [
                          Expanded(child: caption),
                          time,
                        ],
                      ),
                    (final caption, final time) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        ?caption,
                        if (time != null)
                          Align(
                            alignment:
                                timeAndStatusPosition ==
                                    TimeAndStatusPosition.start
                                ? AlignmentDirectional.centerStart
                                : AlignmentDirectional.centerEnd,
                            child: time,
                          ),
                      ],
                    ),
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

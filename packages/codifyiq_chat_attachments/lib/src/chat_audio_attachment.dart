import 'package:codifyiq_audio_message/codifyiq_audio_message.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart';

import 'chat_attachment_labels.dart';
import 'chat_style.dart';
import 'time_and_status.dart';

/// An audio message bubble: an [AudioMessageWidget] with an optional caption
/// and the message's time and status below it.
///
/// [ChatAttachments] builds one for every audio message. Use it directly when
/// you write your own `audioMessageBuilder`.
class ChatAudioAttachment extends StatelessWidget {
  /// Creates a [ChatAudioAttachment].
  ///
  /// [source] is the audio to play and [id] identifies it to [controller].
  const ChatAudioAttachment({
    super.key,
    required this.source,
    required this.isSentByMe,
    this.id,
    this.controller,
    this.duration,
    this.caption,
    this.maxWidth = 280,
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

  /// The audio to play.
  final AudioMessageSource source;

  /// Whether the current user sent the message, which picks the bubble's
  /// colours and whether the status is shown.
  final bool isSentByMe;

  /// Identifies the message to [controller], for example its id.
  final Object? id;

  /// The audio controller the chat screen shares between its messages, so
  /// one plays at a time and playback survives scrolling. Without it, the
  /// player has its own and stops when the bubble is disposed.
  final AudioMessageController? controller;

  /// The audio's length, shown until it has loaded.
  final Duration? duration;

  /// Text shown below the player.
  final String? caption;

  /// The widest the bubble grows.
  final double maxWidth;

  /// The bubble's corner radius. Defaults to the `ChatTheme`'s shape.
  final BorderRadiusGeometry? borderRadius;

  /// The message's status. While it is [MessageStatus.sending] a progress
  /// bar runs below the player, and [MessageStatus.error] is marked beside
  /// the time.
  final MessageStatus? status;

  /// The upload's progress from 0 to 1 while [status] is
  /// [MessageStatus.sending]. Without it the bar runs indeterminately.
  final Stream<double>? uploadProgress;

  /// When the message was sent.
  final DateTime? time;

  /// Whether [time] is shown.
  final bool showTime;

  /// Whether [status] is shown next to the time, for the current user's
  /// messages.
  final bool showStatus;

  /// Whether the time and status sit at the start or the end of the bubble.
  /// [TimeAndStatusPosition.inline] places them at the end.
  final TimeAndStatusPosition timeAndStatusPosition;

  /// A widget above the player, such as the author's name.
  final Widget? topWidget;

  /// Text the player shows and announces.
  final ChatAttachmentLabels labels;

  @override
  Widget build(BuildContext context) {
    final theme = chatThemeOf(context);
    final (background, foreground) = bubbleColors(
      theme,
      isSentByMe: isSentByMe,
    );
    final shownTime = showTime ? time : null;
    final shownStatus = showStatus && isSentByMe ? status : null;
    // Marked like the other bubbles' failures, unless the status shows it.
    final marksFailure =
        status == MessageStatus.error && shownStatus != MessageStatus.error;
    final text = caption;
    final top = topWidget;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: background,
        borderRadius: borderRadius ?? theme.shape,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                timeAndStatusPosition == TimeAndStatusPosition.start
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              if (top != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: top,
                  ),
                ),
              AudioMessageWidget(
                source: source,
                id: id,
                controller: controller,
                duration: duration,
                color: foreground,
                textStyle: theme.typography.bodySmall.copyWith(
                  color: foreground.withValues(alpha: 0.8),
                ),
                errorLabel: labels.audioError,
                playTooltip: labels.play,
                pauseTooltip: labels.pause,
                retryTooltip: labels.retry,
              ),
              if (status == MessageStatus.sending)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 0, 4),
                  child: StreamBuilder<double>(
                    stream: uploadProgress,
                    builder: (context, snapshot) => LinearProgressIndicator(
                      // Full once the upload's stream closes.
                      value: snapshot.connectionState == ConnectionState.done
                          ? 1
                          : snapshot.data,
                      color: foreground,
                      backgroundColor: foreground.withValues(alpha: 0.2),
                      semanticsLabel: labels.sending,
                    ),
                  ),
                ),
              if (text != null && text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 0, 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      text,
                      style: theme.typography.bodyMedium.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              if (shownTime != null || shownStatus != null || marksFailure)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      if (marksFailure)
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: foreground,
                          semanticLabel: labels.notSent,
                        ),
                      if (shownTime != null || shownStatus != null)
                        TimeAndStatus(
                          time: shownTime,
                          status: shownStatus,
                          color: foreground.withValues(alpha: 0.8),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

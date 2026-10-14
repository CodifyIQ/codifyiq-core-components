import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart';

import 'attachment_source.dart';
import 'chat_attachment_labels.dart';
import 'chat_style.dart';
import 'time_and_status.dart';

/// A file message bubble: an icon, the file name, its type and size, and the
/// message's time and status.
///
/// PDFs get a PDF icon unless [icon] is given. [ChatAttachments] builds one for every file message.
/// Use it directly when you write your own `fileMessageBuilder`.
class ChatFileAttachment extends StatelessWidget {
  /// Creates a [ChatFileAttachment].
  ///
  /// [name] is the file name, [size] its size in bytes and [mimeType] its
  /// MIME type.
  const ChatFileAttachment({
    super.key,
    required this.name,
    required this.isSentByMe,
    this.size,
    this.mimeType,
    this.onTap,
    this.icon,
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

  /// The file name, shown on one line with an ellipsis when long.
  final String name;

  /// Whether the current user sent the message, which picks the bubble's
  /// colours and whether the status is shown.
  final bool isSentByMe;

  /// The file's size in bytes, if known.
  final int? size;

  /// The file's MIME type, if known.
  final String? mimeType;

  /// Called when the bubble is tapped. If `null`, the bubble leaves taps to
  /// the widgets around it, such as `Chat`'s `onMessageTap`.
  final VoidCallback? onTap;

  /// The file's icon. Defaults to a PDF icon for PDFs and a generic file
  /// icon otherwise.
  final IconData? icon;

  /// The widest the bubble grows.
  final double maxWidth;

  /// The bubble's corner radius. Defaults to the `ChatTheme`'s shape.
  final BorderRadiusGeometry? borderRadius;

  /// The message's status. While it is [MessageStatus.sending] a progress
  /// ring surrounds the file icon, and [MessageStatus.error] replaces the
  /// icon with an error mark.
  final MessageStatus? status;

  /// The upload's progress from 0 to 1 while [status] is
  /// [MessageStatus.sending]. Without it the ring spins.
  final Stream<double>? uploadProgress;

  /// When the message was sent.
  final DateTime? time;

  /// Whether [time] is shown.
  final bool showTime;

  /// Whether [status] is shown next to the time, for the current user's
  /// messages.
  final bool showStatus;

  /// Where the time and status sit: below the details at the start or end,
  /// or [TimeAndStatusPosition.inline] at the end of the type and size line.
  final TimeAndStatusPosition timeAndStatusPosition;

  /// A widget above the file, such as the author's name.
  final Widget? topWidget;

  /// Text the bubble announces.
  final ChatAttachmentLabels labels;

  @override
  Widget build(BuildContext context) {
    final theme = chatThemeOf(context);
    final (background, foreground) = bubbleColors(
      theme,
      isSentByMe: isSentByMe,
    );
    final details = [
      ?fileExtension(name),
      if (size case final size?) formatFileSize(size),
    ].join(' · ');
    final shownTime = showTime ? time : null;
    final shownStatus = showStatus && isSentByMe ? status : null;
    final timeAndStatus = shownTime != null || shownStatus != null
        ? TimeAndStatus(
            time: shownTime,
            status: shownStatus,
            color: foreground.withValues(alpha: 0.8),
          )
        : null;
    final isInline = timeAndStatusPosition == TimeAndStatusPosition.inline;
    final detailsStyle = theme.typography.bodySmall.copyWith(
      color: foreground.withValues(alpha: 0.8),
    );
    final top = topWidget;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: background,
        borderRadius: borderRadius ?? theme.shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            // As flutter_chat_ui's text bubbles do, an invisible copy of
            // the time reserves its line, so the bubble is as wide as its
            // widest line, and the time sits at either edge of it.
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (top != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: top,
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                status == MessageStatus.error
                                    ? Icons.error_outline
                                    : icon ??
                                          (isPdf(name, mimeType)
                                              ? Icons.picture_as_pdf_outlined
                                              : Icons
                                                    .insert_drive_file_outlined),
                                color: foreground,
                                size: status == MessageStatus.sending ? 20 : 32,
                                semanticLabel: status == MessageStatus.error
                                    ? labels.notSent
                                    : null,
                              ),
                              if (status == MessageStatus.sending)
                                StreamBuilder<double>(
                                  stream: uploadProgress,
                                  builder: (context, snapshot) =>
                                      CircularProgressIndicator(
                                        // Full once the upload's stream closes.
                                        value:
                                            snapshot.connectionState ==
                                                ConnectionState.done
                                            ? 1
                                            : snapshot.data,
                                        color: foreground,
                                        strokeWidth: 3,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 36,
                                              height: 36,
                                            ),
                                        semanticsLabel: labels.sending,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.bodyMedium.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (details.isNotEmpty ||
                                  (isInline && timeAndStatus != null))
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 8,
                                  children: [
                                    if (details.isNotEmpty)
                                      Flexible(
                                        child: Text(
                                          details,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: detailsStyle,
                                        ),
                                      ),
                                    if (isInline) ?timeAndStatus,
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isInline && timeAndStatus != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Opacity(opacity: 0, child: timeAndStatus),
                      ),
                  ],
                ),
                if (!isInline && timeAndStatus != null)
                  PositionedDirectional(
                    bottom: 0,
                    start: timeAndStatusPosition == TimeAndStatusPosition.start
                        ? 0
                        : null,
                    end: timeAndStatusPosition == TimeAndStatusPosition.start
                        ? null
                        : 0,
                    child: timeAndStatus,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

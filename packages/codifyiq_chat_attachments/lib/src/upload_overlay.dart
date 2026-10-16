import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart';

import 'chat_attachment_labels.dart';

/// Covers an image or video bubble while its message is sending, with the
/// upload's progress when known, or marks it when sending failed. Draws
/// nothing for any other [status].
class UploadOverlay extends StatelessWidget {
  /// Creates an [UploadOverlay].
  const UploadOverlay({
    super.key,
    this.status,
    this.progress,
    this.labels = const ChatAttachmentLabels(),
  });

  /// The message's status.
  final MessageStatus? status;

  /// The upload's progress from 0 to 1. Without it, or before its first
  /// value, the indicator spins. Once it closes, the indicator is full.
  final Stream<double>? progress;

  /// Text the indicators announce.
  final ChatAttachmentLabels labels;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      MessageStatus.sending => IgnorePointer(
        child: ColoredBox(
          color: colorScheme.scrim.withValues(alpha: 0.4),
          child: Center(
            child: StreamBuilder<double>(
              stream: progress,
              builder: (context, snapshot) => CircularProgressIndicator(
                // The stream closes when the upload completes, which the
                // ring keeps showing until the message is marked sent.
                value: snapshot.connectionState == ConnectionState.done
                    ? 1
                    : snapshot.data,
                color: Colors.white,
                backgroundColor: Colors.white24,
                semanticsLabel: labels.sending,
              ),
            ),
          ),
        ),
      ),
      MessageStatus.error => IgnorePointer(
        child: Align(
          alignment: AlignmentDirectional.topEnd,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.errorContainer,
              child: Icon(
                Icons.error_outline,
                size: 20,
                color: colorScheme.onErrorContainer,
                semanticLabel: labels.notSent,
              ),
            ),
          ),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart';

import 'chat_style.dart';

/// A message's time and, for the current user's messages, its status, in
/// `Chat`'s time format.
class TimeAndStatus extends StatelessWidget {
  /// Creates a [TimeAndStatus].
  const TimeAndStatus({
    super.key,
    required this.time,
    required this.status,
    required this.color,
  });

  /// When the message was sent, or `null` to leave the time out.
  final DateTime? time;

  /// The message's status, or `null` to leave it out.
  final MessageStatus? status;

  /// Colour of the text and icon.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final time = this.time;
    final status = this.status;
    final style = chatThemeOf(
      context,
    ).typography.labelSmall.copyWith(color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        if (time != null)
          Text(timeFormatOf(context).format(time.toLocal()), style: style),
        if (status == MessageStatus.sending)
          SizedBox.square(
            dimension: 8,
            child: CircularProgressIndicator(color: color, strokeWidth: 1.5),
          )
        else if (status != null)
          Icon(getIconForStatus(status), color: color, size: 12),
      ],
    );
  }
}

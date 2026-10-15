# codifyiq_audio_message example

```dart
import 'package:codifyiq_audio_message/codifyiq_audio_message.dart';
import 'package:material_ui/material_ui.dart';

// Simplest form — the widget manages its own controller.
Widget buildPlayer() {
  return AudioMessageWidget(
    source: AudioMessageSource.uri(Uri.parse('https://example.com/clip.m4a')),
    duration: const Duration(seconds: 42),
  );
}

// In a list of messages, share one controller owned by the screen, so one
// message plays at a time and playback survives scrolling.
Widget buildMessagePlayer(AudioMessageController controller, String id) {
  return AudioMessageWidget(
    id: id,
    source: AudioMessageSource.uri(Uri.parse('https://example.com/$id.m4a')),
    controller: controller,
  );
}
```

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

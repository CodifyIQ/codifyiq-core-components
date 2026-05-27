# codifyiq_audio_message example

```dart
import 'package:codifyiq_audio_message/codifyiq_audio_message.dart';
import 'package:flutter/material.dart';

// Simplest form — the widget manages its own controller from the URL.
Widget buildPlayer() {
  return const AudioMessage(url: 'https://example.com/clip.m4a');
}

// Drive it yourself for finer control or a custom playback backend.
Widget buildDrivenPlayer() {
  final controller = AudioMessageController('https://example.com/clip.m4a');
  return AudioMessage(url: controller.url, controller: controller);
}
```

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

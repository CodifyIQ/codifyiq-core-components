# codifyiq_audio_message

[![pub package](https://img.shields.io/pub/v/codifyiq_audio_message.svg)](https://pub.dev/packages/codifyiq_audio_message)

A chat-style audio message player with play/pause, a scrubbable progress bar, and a duration
readout. Playback is driven through a pluggable `AudioPlayerBackend` interface, which defaults
to a [`just_audio`](https://pub.dev/packages/just_audio) binding but can be swapped for testing
or unsupported platforms.

## Installation

```yaml
dependencies:
  codifyiq_audio_message: ^1.0.0
```

## Usage

```dart
import 'package:codifyiq_audio_message/codifyiq_audio_message.dart';

// The simplest form manages its own controller from a URL.
AudioMessage(url: 'https://example.com/clip.m4a');

// Or drive it yourself for finer control (and a custom playback backend):
final controller = AudioMessageController('https://example.com/clip.m4a');
AudioMessage(url: controller.url, controller: controller);
```

Pass a custom `backend` to `AudioMessageController` to substitute the default `just_audio`
binding.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

# codifyiq_audio_message

[![pub package](https://img.shields.io/pub/v/codifyiq_audio_message.svg)](https://pub.dev/packages/codifyiq_audio_message)

A chat-style audio message player with play/pause, a scrubbable progress bar, and a duration
readout. Playback is driven through a pluggable `AudioPlayerBackend` interface, which defaults
to a [`just_audio`](https://pub.dev/packages/just_audio) binding but can be swapped for testing
or unsupported platforms.

## Installation

```yaml
dependencies:
  codifyiq_audio_message: ^2.0.0
```

## Usage

```dart
import 'package:codifyiq_audio_message/codifyiq_audio_message.dart';

AudioMessageWidget(
  source: AudioMessageSource.uri(Uri.parse('https://example.com/clip.m4a')),
  // Shown until the clip loads, if you know it.
  duration: const Duration(seconds: 42),
);
```

`AudioMessageSource` also has `.file` for local files and `.asset` for bundled assets, and
`.uri` takes HTTP `headers` for private storage (ignored on the web, where browsers don't allow
them).

### Lists of messages

On its own, each player has its own controller, which stops when the player is disposed. In a
chat, where off-screen messages are disposed as the list scrolls, share one
`AudioMessageController` owned by the screen and give each player its message's `id`:

```dart
final audio = AudioMessageController(); // dispose() with the screen

AudioMessageWidget(
  id: message.id,
  source: AudioMessageSource.uri(Uri.parse(message.source)),
  duration: message.duration,
  controller: audio,
);
```

Then starting one message stops the one that was playing, and a message keeps playing when
it scrolls out of view; scrolled back, its player shows the current position.

### Appearance

`color` sets the play button and slider, and `textStyle` the time readout, for example to
match a sent or received chat bubble. The error label and tooltips can be replaced for
localisation.

### Playback backend

Pass a custom `backend` to `AudioMessageController` to substitute the default `just_audio`
binding, for example a test double.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

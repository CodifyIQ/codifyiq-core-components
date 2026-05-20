# flyer_chat_video_message

Video message widget for [Flutter Chat UI](https://github.com/flyerhq/flutter_chat_ui).

## Features

- Renders `VideoMessage` as a fixed-aspect-ratio thumbnail with a play overlay
- Prefers backend-provided thumbnail URLs; falls back to locally generated thumbnails
- Loading, error, and upload-progress states
- Optional duration badge
- Fully customisable via builder callbacks
- **No video playback** — purely a UI renderer

> Thumbnail generation via `video_thumbnail` is supported on Android, iOS, and
> macOS. On web and other platforms the widget shows a placeholder until a
> `thumbnailUrl` is supplied in `message.metadata`.

## Installation

```yaml
dependencies:
  flyer_chat_video_message: ^1.0.0
```

## Usage

Wire the widget into `flutter_chat_ui` via `Builders`:

```dart
Chat(
  builders: Builders(
    videoMessageBuilder: (context, message, index, {
      required isSentByMe,
      groupStatus,
    }) =>
        FlyerChatVideoMessage(message: message, index: index),
  ),
)
```

### Providing a thumbnail and duration

Pass optional metadata on the `VideoMessage`:

```dart
VideoMessage(
  id: 'msg-1',
  authorId: 'user-1',
  source: 'https://example.com/video.mp4',
  width: 1280,
  height: 720,
  metadata: {
    'thumbnailUrl': 'https://example.com/thumb.jpg',
    'duration': '1:23',
  },
)
```

`thumbnailUrl` is used directly as a network image (preferred over generation).
`duration` is rendered as a badge in the bottom-left corner of the thumbnail.

## Customisation

### Custom thumbnail widget

```dart
FlyerChatVideoMessage(
  message: message,
  index: index,
  thumbnailBuilder: (context, message) =>
      Image.network(message.source, fit: BoxFit.cover),
)
```

### Custom play overlay

```dart
FlyerChatVideoMessage(
  message: message,
  index: index,
  overlay: const Icon(Icons.play_circle, color: Colors.white, size: 48),
)
```

### Custom loading and error states

```dart
FlyerChatVideoMessage(
  message: message,
  index: index,
  loadingBuilder: (_) => const Center(child: MyLoadingSpinner()),
  errorBuilder: (_) => const Center(child: Icon(Icons.broken_image)),
)
```

### Replace the entire content

```dart
FlyerChatVideoMessage(
  message: message,
  index: index,
  customVideoWidget: MyCustomVideoPreview(message: message),
)
```

When `customVideoWidget` is set, `thumbnailBuilder`, `loadingBuilder`,
`errorBuilder`, and `overlay` are all ignored.

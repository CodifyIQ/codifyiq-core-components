# codifyiq_video_viewer example

```dart
import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';
import 'package:material_ui/material_ui.dart';

Widget buildClip(BuildContext context) {
  final source = VideoSource.uri(Uri.parse('https://example.com/clip.mp4'));
  return VideoThumbnailTile(
    thumbnail: const NetworkImage('https://example.com/clip.jpg'),
    duration: const Duration(seconds: 42),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VideoViewerScreen(source: source, title: 'clip.mp4'),
      ),
    ),
  );
}
```

> HTTP headers on `VideoSource.uri` are ignored on Flutter web, and `VideoSource.file` is
> unsupported there.

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

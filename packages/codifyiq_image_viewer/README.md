# codifyiq_image_viewer

[![pub package](https://img.shields.io/pub/v/codifyiq_image_viewer.svg)](https://pub.dev/packages/codifyiq_image_viewer)

A full-screen image viewer with swipe paging, pinch-to-zoom, and custom actions, built on
[`photo_view`](https://pub.dev/packages/photo_view). Images may come from the network, assets,
a local file, or any custom `ImageProvider`.

## Installation

```yaml
dependencies:
  codifyiq_image_viewer: ^1.0.0
```

## Usage

```dart
import 'package:codifyiq_image_viewer/codifyiq_image_viewer.dart';

ImageViewerWidget(
  items: [
    ImageViewerItem.network('https://example.com/a.jpg'),
    ImageViewerItem.asset('assets/b.png'),
  ],
);
```

> **Web note:** `ImageViewerItem.file` is not supported on Flutter web. Use `.network`,
> `.asset`, or a custom `ImageProvider` on the web target.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

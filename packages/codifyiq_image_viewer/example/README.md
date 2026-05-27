# codifyiq_image_viewer example

```dart
import 'package:codifyiq_image_viewer/codifyiq_image_viewer.dart';
import 'package:flutter/material.dart';

Widget buildGallery() {
  return ImageViewerWidget(
    items: [
      ImageViewerItem.network('https://example.com/a.jpg'),
      ImageViewerItem.asset('assets/b.png'),
    ],
  );
}
```

> `ImageViewerItem.file` is unsupported on Flutter web; use `.network`, `.asset`, or a custom
> `ImageProvider` on the web target.

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

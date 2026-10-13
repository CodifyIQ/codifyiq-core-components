# codifyiq_image_viewer

[![pub package](https://img.shields.io/pub/v/codifyiq_image_viewer.svg)](https://pub.dev/packages/codifyiq_image_viewer)

A full-screen image viewer with swipe paging, pinch-to-zoom, and custom actions, built on
[`photo_view`](https://pub.dev/packages/photo_view). Images may come from the network, assets,
a local file, or any custom `ImageProvider`.

## Installation

```yaml
dependencies:
  codifyiq_image_viewer: ^2.1.0
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

### Actions

Share, Download and Delete appear when you supply their callbacks. Give items an `id` and
`filename` so the callbacks know which record to act on, and add your own menu entries with
`actions`:

```dart
ImageViewerWidget(
  items: [
    for (final photo in photos)
      ImageViewerItem.network(photo.url, id: photo.id, filename: photo.filename),
  ],
  onDownload: (item, index) => download(item.id!, item.filename!),
  onDelete: (item, index) => delete(item.id!),
  actions: [
    ImageViewerAction(
      label: 'Set as featured',
      icon: Icons.star_outline,
      onSelected: (item, index) => setFeatured(item.id!),
    ),
  ],
);
```

`items` can change while the viewer is open. After a delete, rebuild with the shorter list and
the viewer moves to the neighbouring image. Removing from the list you passed in works just as
well as passing a new one.

* Give every item an `id` when the list can change. It is how the viewer recognises the image
  being viewed after the change.
* `items` must never be empty. When the last image is deleted, close the viewer
  (`Navigator.of(context).pop()`) instead of rebuilding it with an empty list.
* Zoom returns to fit-to-screen when images are removed, reordered or inserted ahead of others.

> **Web note:** `ImageViewerItem.file` is not supported on Flutter web. Use `.network`,
> `.asset`, or a custom `ImageProvider` on the web target.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

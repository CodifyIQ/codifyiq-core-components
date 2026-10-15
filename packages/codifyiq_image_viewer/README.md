# codifyiq_image_viewer

[![pub package](https://img.shields.io/pub/v/codifyiq_image_viewer.svg)](https://pub.dev/packages/codifyiq_image_viewer)

A full-screen image viewer with swipe paging, pinch-to-zoom, and custom actions, built on
[`photo_view`](https://pub.dev/packages/photo_view). Images may come from the network, assets,
a local file, or any custom `ImageProvider`.

## Installation

```yaml
dependencies:
  codifyiq_image_viewer: ^2.0.0
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

### Thumbnails and placeholders

When a grid or list already shows a small version of each image, pass it as the item's
`placeholder`. The viewer shows it straight away and swaps in the full image once it has
downloaded, instead of showing a spinner:

```dart
ImageViewerItem.network(
  photo.url,
  placeholder: NetworkImage(photo.thumbnailUrl), // the provider the grid used
  heroTag: photo.id,
);
```

Give the placeholder the same aspect ratio as the full image. One that fails to load is ignored.

### Layout

The viewer follows the Material 3 breakpoints:

* **Phones (windows narrower than 600dp, or shorter than 480dp as in landscape):** the image
  fills the screen and the header and footer float over it on a dark gradient. Tapping the
  image hides or shows them.
* **Tablets, desktop and most browser windows:** the header and footer sit above and below the
  image, which fits between them with the 24dp Material margin, so they never cover it.

Override either choice:

```dart
ImageViewerWidget(
  items: items,
  controlsLayout: ImageViewerControlsLayout.inset, // or .overlay
  contentPadding: const EdgeInsets.all(16),        // space around the image
  controlsHideOnTap: false,                         // keep overlay controls up
);
```

### Header and footer

The header shows the image's `title` (or its `filename`) above the page indicator, and the
footer shows its `caption` with a row of page dots (for 2 to 20 images). Replace either with
your own:

```dart
ImageViewerWidget(
  items: [
    ImageViewerItem.network(
      photo.url,
      title: photo.name,
      caption: photo.description,
    ),
  ],
  titleBuilder: (context, item, index, total) => Text(item.title ?? ''),
  footerBuilder: (context, item, index, total) =>
      item.caption == null ? null : Text(item.caption!), // null: no footer
);
```

`pageIndicatorBuilder` still changes the "1 / 5" text on its own.

### Actions

Share, Download and Delete appear when you supply their callbacks. Give items an `id` and
`filename` so the callbacks know which record to act on, and add your own actions with
`actions`, as overflow menu entries or, with `showInAppBar`, header buttons. `isVisible` offers
an action only for some images:

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
      showInAppBar: true,
      isVisible: (item, index) => item.id != featuredId,
      onSelected: (item, index) => setFeatured(item.id!),
    ),
  ],
);
```

The viewer reads `isVisible` each time it rebuilds. If the viewer is its own route, rebuild it
when the answer changes, for example with a `ValueListenableBuilder` around it in the route's
builder, so the button disappears as soon as the image becomes featured.

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

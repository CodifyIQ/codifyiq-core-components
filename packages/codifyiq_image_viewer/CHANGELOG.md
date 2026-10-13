## 2.1.0

* `ImageViewerItem.id` and `ImageViewerItem.filename` — give each image an identifier and a file name. Both are handed back in the Share, Download, Delete and custom action callbacks, so you can act on the right record and name the saved file without mapping the index back to your own model.
* `ImageViewerWidget.actions` — add your own entries (for example "Set as featured") to the overflow menu with `ImageViewerAction`, alongside the built-in Share, Download and Delete.
* The viewer now handles `items` changing while it is open, such as removing an image after Delete. It stays on the image being viewed when that image is still in the list, and otherwise shows the one now in its place. This works whether you pass a new list or change the one you passed in. Previously the page indicator went out of range (e.g. "3 / 2"), actions threw after a removal, and paging onto a newly added image threw. Zoom returns to fit-to-screen when images are removed, reordered or inserted ahead of others, and `items` must still never be empty — close the viewer when the last image is removed.

## 2.0.0

* **Breaking:** now built on [`material_ui`](https://pub.dev/packages/material_ui), Flutter's standalone Material library, instead of the copy bundled in the Flutter SDK. Your app must use `material_ui` too, otherwise the widgets won't pick up your theme. To migrate your app, run `dart fix --apply --code=migrate_design_widgets`.
* **Breaking:** requires Flutter 3.44 / Dart 3.12 or later.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `ImageViewerWidget` — a full-screen viewer with swipe paging, pinch-to-zoom, and custom actions, supporting network, asset, file, and custom image sources.

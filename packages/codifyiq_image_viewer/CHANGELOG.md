## 2.0.0

* **Breaking:** now built on [`material_ui`](https://pub.dev/packages/material_ui), Flutter's standalone Material library, instead of the copy bundled in the Flutter SDK. Your app must use `material_ui` too, otherwise the widgets won't pick up your theme. To migrate your app, run `dart fix --apply --code=migrate_design_widgets`.
* **Breaking:** requires Flutter 3.44 / Dart 3.12 or later.
* **Adaptive layout, following the Material 3 breakpoints.** In windows narrower than 600dp or shorter than 480dp, such as a phone held either way, the image fills the screen with the header and footer floating over it on a dark gradient, and tapping the image hides or shows them. In wider windows, the header and footer sit above and below the image, which fits between them with a 24dp margin, so they never cover it. Previously the image always ran under the header and, on web, to the window's edges. Choose the layout with `controlsLayout`, the space around the image with `contentPadding`, and turn tap-to-hide off with `controlsHideOnTap: false`.
* The header title is now left-aligned and shows the image's `title` (or its `filename`) above the page indicator, instead of the indicator alone in the centre. Replace it with `titleBuilder`.
* Escape closes the viewer, and the close button is left out when there is no route to go back to.
* New footer showing `ImageViewerItem.caption` and, for 2 to 20 images, a row of page dots. Replace it, or remove it, with `footerBuilder`.
* `ImageViewerAction.showInAppBar` makes an action a header button instead of a menu entry, and `ImageViewerAction.isVisible` offers it only for some images, such as "Set as featured" on images that aren't already.
* `ImageViewerItem.id` and `ImageViewerItem.filename` — give each image an identifier and a file name. Both are handed back in the Share, Download, Delete and custom action callbacks, so you can act on the right record and name the saved file without mapping the index back to your own model.
* `ImageViewerWidget.actions` — add your own entries (for example "Set as featured") to the overflow menu with `ImageViewerAction`, alongside the built-in Share, Download and Delete.
* The viewer now handles `items` changing while it is open, such as removing an image after Delete. It stays on the image being viewed when that image is still in the list, and otherwise shows the one now in its place. This works whether you pass a new list or change the one you passed in. Previously the page indicator went out of range (e.g. "3 / 2"), actions threw after a removal, and paging onto a newly added image threw. Zoom returns to fit-to-screen when images are removed, reordered or inserted ahead of others, and `items` must still never be empty — close the viewer when the last image is removed.
* `ImageViewerItem.placeholder` — a low-resolution image, such as the thumbnail the viewer was opened from, shown in place of the loading spinner until the full image has loaded. Pass the same image the thumbnail used and it appears at once, so a Hero from the thumbnail lands on a picture instead of an empty page. Available on the `asset`, `network` and `file` constructors too.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `ImageViewerWidget` — a full-screen viewer with swipe paging, pinch-to-zoom, and custom actions, supporting network, asset, file, and custom image sources.

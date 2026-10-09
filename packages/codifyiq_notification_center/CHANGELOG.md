## 2.0.0

* **Breaking:** now built on [`material_ui`](https://pub.dev/packages/material_ui), Flutter's standalone Material library, instead of the copy bundled in the Flutter SDK. Your app must use `material_ui` too, otherwise the widgets won't pick up your theme. To migrate your app, run `dart fix --apply --code=migrate_design_widgets`.
* **Breaking:** requires Flutter 3.44 / Dart 3.12 or later.

## 1.0.1

* A running notification now shows a single progress indicator instead of two. An indeterminate task (no `progress` value) shows just the leading spinner; a task that reports a determinate `progress` shows just the linear progress bar, with no leading glyph. Previously every running item showed both a spinner and a bar at once.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `NotificationBellButton`, `NotificationCenterController`, `NotificationCenterPanel`, `NotificationCenterPage`, and `NotificationCenterScope` — a Play Store-style notification center with a stoplight-coded bell badge for tracking long-running tasks.

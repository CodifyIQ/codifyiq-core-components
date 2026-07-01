## 1.0.1

* A running notification now shows a single progress indicator instead of two. An indeterminate task (no `progress` value) shows just the leading spinner; a task that reports a determinate `progress` shows just the linear progress bar, with no leading glyph. Previously every running item showed both a spinner and a bar at once.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `NotificationBellButton`, `NotificationCenterController`, `NotificationCenterPanel`, `NotificationCenterPage`, and `NotificationCenterScope` — a Play Store-style notification center with a stoplight-coded bell badge for tracking long-running tasks.

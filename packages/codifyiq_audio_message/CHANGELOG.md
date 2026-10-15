## 2.0.0

* **Breaking:** now built on [`material_ui`](https://pub.dev/packages/material_ui), Flutter's standalone Material library, instead of the copy bundled in the Flutter SDK. Your app must use `material_ui` too, otherwise the widgets won't pick up your theme. To migrate your app, run `dart fix --apply --code=migrate_design_widgets`.
* **Breaking:** requires Flutter 3.44 / Dart 3.12 or later.
* **Breaking:** `AudioMessageWidget` takes an `AudioMessageSource` instead of a `url` string: `.uri` (with optional HTTP `headers` for private storage), `.file` for local files, or `.asset` for bundled assets. `AudioPlayerBackend.setUrl` is now `setSource`.
* **Breaking:** one `AudioMessageController` now plays many messages. Create it without a URL, share it between the players on a screen, and give each player an `id`: only one message plays at a time, and a message keeps playing when its player is disposed, for example when a chat bubble scrolls out of view. A player without a controller still creates its own.
* `duration` shows a known length before the clip loads, instead of `00:00`.
* `color` and `textStyle` set the play button, slider and time readout, for example to match a chat bubble.
* Dragging the slider now moves smoothly and seeks once when released, instead of fighting playback and jumping back to the current position. The time readout follows the drag, and the play button no longer flickers while seeking during playback.
* `AudioMessageController.seek` moves `position` to the target at once, and a failed seek shows the error state.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `AudioMessage`, `AudioMessageController`, and the `AudioPlayerBackend` interface — a chat-style audio player with play/pause, scrubbing, and a swappable playback backend (defaults to `just_audio`).

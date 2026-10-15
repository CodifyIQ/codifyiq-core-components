## 2.0.0

* **Breaking:** now built on [`material_ui`](https://pub.dev/packages/material_ui), Flutter's standalone Material library, instead of the copy bundled in the Flutter SDK. Your app must use `material_ui` too, otherwise the widgets won't pick up your theme. To migrate your app, run `dart fix --apply --code=migrate_design_widgets`.
* **Breaking:** requires Flutter 3.44 / Dart 3.12 or later.
* **Breaking:** requires `adaptive_theme` 3.8.0 or later, the first release built on `material_ui`.
* `BrightnessSubmenu` — a "Theme" submenu you can drop into your own `MenuAnchor` (e.g. an account or overflow menu) instead of adding a separate button. Its icon reflects the current mode, and all labels can be overridden.
* `brightnessMenuItems(context)` — the Light / Dark / System menu items on their own, to spread inline into any menu.
* `BrightnessButton` gains `tooltip`, `lightLabel`, `darkLabel`, and `systemLabel`, so its text can be localized like the submenu's.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `BrightnessButton` — a Light / Dark / System theme toggle built on AdaptiveTheme.

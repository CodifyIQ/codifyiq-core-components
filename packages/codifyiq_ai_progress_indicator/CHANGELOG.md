## 2.0.0

* **Breaking:** now built on [`material_ui`](https://pub.dev/packages/material_ui), Flutter's standalone Material library, instead of the copy bundled in the Flutter SDK. Your app must use `material_ui` too, otherwise the widgets won't pick up your theme. To migrate your app, run `dart fix --apply --code=migrate_design_widgets`.
* **Breaking:** requires Flutter 3.44 / Dart 3.12 or later.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `AiProgressIndicator` — a shimmer progress indicator for AI-enabled actions with theme-derived colors, configurable shimmer period/intensity, and an optional progress spinner.

## 2.0.0

* **Breaking:** now built on [`material_ui`](https://pub.dev/packages/material_ui), Flutter's standalone Material library, instead of the copy bundled in the Flutter SDK. Your app must use `material_ui` too, otherwise the widgets won't pick up your theme. To migrate your app, run `dart fix --apply --code=migrate_design_widgets`.
* **Breaking:** requires Flutter 3.44 / Dart 3.12 or later.
* The Markdown content keeps following your app's light and dark themes; no extra setup is needed for it.

## 1.1.0

* Shortened the acceptance button labels so they no longer wrap to two lines on
  small screens: `Read to accept` before the terms are scrolled to the end, and
  `Accept` once they are. **Breaking for anyone relying on the old wording** —
  pass `readPromptLabel` and `acceptLabel` to restore it.
* Added `readPromptLabel` and `acceptLabel` so the button can be localized or
  reworded for a host's tone or required assent wording.
* Added `isProcessing`, which disables the acceptance button and replaces its
  label with a progress indicator while an acceptance is being recorded —
  matching `SocialSignInScreen`'s parameter of the same name.
* A null `onAccepted` now disables the acceptance button instead of leaving it
  enabled and silently ignoring taps.
* Fixed markdown headings keeping the previous brightness's colour when the app
  switched between light and dark mode while the terms were on screen, which
  left them washed out and close to unreadable until the screen was reopened.
* Replacing `termsContent` now closes the acceptance gate again, so a new
  document can no longer be accepted on the strength of having read the one it
  replaced. The terms also scroll back to the top.
* The in-flight progress indicator now takes the acceptance button's own
  foreground colour, so it matches the label it stands in for under a host's
  `filledButtonTheme` instead of the surrounding page's text colour.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `TermsAndConditionsWidget` — scrollable Markdown terms with a scroll-gated acceptance checkbox and an `onAccepted` callback.

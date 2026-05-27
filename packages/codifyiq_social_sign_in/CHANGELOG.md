## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `SocialSignInScreen` and `SocialSignInButton` — a presentational sign-in layout with pluggable provider buttons, a processing state, an optional Microsoft button, and a reviewer-login easter egg.
* `SocialSignInError`, the `error` parameter, and the `onError` callback — separate the user-facing message from the underlying technical detail so raw backend diagnostics (e.g. OAuth scope errors) are captured for your own logging but never shown to users.

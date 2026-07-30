## 1.1.0

* Email magic-link sign-in. Add a `MagicLinkButton` with `onSubmitEmail` to
  `signInButtons` for an inline flow: email entry, a "check your inbox"
  confirmation, and resend with a configurable cooldown. Also exported
  standalone as `MagicLinkForm` for use outside `SocialSignInScreen`.
* Cross-device code fallback: provide `onSubmitCode` and the confirmation
  panel adds entry for the short code included in the email, for devices
  where the link can't be tapped.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `SocialSignInScreen` and `SocialSignInButton` — a presentational sign-in layout with pluggable provider buttons, a processing state, an optional Microsoft button, and a reviewer-login easter egg.
* `SocialSignInError`, the `error` parameter, and the `onError` callback — separate the user-facing message from the underlying technical detail so raw backend diagnostics (e.g. OAuth scope errors) are captured for your own logging but never shown to users.

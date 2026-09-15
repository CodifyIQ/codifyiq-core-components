## 1.1.1

* Code-only email sign-in, for apps that can't receive links (e.g. a native
  mobile app without universal links / app links). Pass
  `delivery: MagicLinkDelivery.code` with `onSubmitCode` to `MagicLinkForm`
  and the form's copy talks only about a code: "Email me a code",
  "Sending code…", and "We sent a 6-character code to … Enter it below.",
  with the code field shown as soon as the email is sent.
* `MagicLinkDelivery.link` and `MagicLinkDelivery.linkAndCode` name the
  existing behaviours. `delivery` is optional and defaults from whether
  `onSubmitCode` is set, so existing forms are unchanged;
  `MagicLinkForm.effectiveDelivery` reports the resolved mode.
* `SocialSignInScreen` now respects device safe-area insets: the logo no
  longer sits under the status bar or camera cutout when there is no
  `appBar`, and the `footer` clears the home indicator.

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

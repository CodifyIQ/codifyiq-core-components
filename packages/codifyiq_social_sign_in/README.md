# codifyiq_social_sign_in

[![pub package](https://img.shields.io/pub/v/codifyiq_social_sign_in.svg)](https://pub.dev/packages/codifyiq_social_sign_in)

A complete, purely presentational sign-in screen layout with logo, tagline, social sign-in
buttons, error display, and footer. Consuming apps inject their own branding, buttons, and
authentication callbacks.

## Features

* Customizable logo, tagline, sign-in prompt, and footer.
* A themed error container that shows only a user-safe message — raw backend
  diagnostics are captured via a callback, never displayed (see
  [Error handling](#error-handling)).
* A built-in processing state that replaces the buttons with a progress indicator during
  authentication, preventing duplicate taps.
* `SocialSignInButton` — a companion widget for consistent icon + label button styling.
* An optional **reviewer login easter egg**: tapping the logo a configurable number of times
  reveals a built-in email/password form for app-store reviewers.

## Installation

```yaml
dependencies:
  codifyiq_social_sign_in: ^1.0.0
```

## Usage

```dart
import 'package:codifyiq_social_sign_in/codifyiq_social_sign_in.dart';

SocialSignInScreen(
  logo: Image.asset('assets/logo.png'),
  reviewerLoginEnabled: true,
  onReviewerSignIn: (email, password) => _signIn(email, password),
  signInButtons: [
    SocialSignInButton(icon: googleLogo, label: 'Continue with Google', onPressed: _google),
  ],
);
```

## Error handling

Authentication backends often surface diagnostics that are useful for debugging
but confusing — or alarming — to end users (e.g. *"{(openid, profile,
\"offline_access\")} are reserved scopes and may not be specified in the acquire
token call"*). Wrap failures in a `SocialSignInError`: the screen renders only
the user-safe `message`, while the technical `detail` is handed to `onError`
for your diagnostics (Crashlytics, Sentry, server logs) and never shown.

```dart
SocialSignInScreen(
  // ...
  error: _error, // SocialSignInError? held in your state
  onError: (error) => logger.error('Sign-in failed', error.detail),
  signInButtons: [...],
);

// In your sign-in catch block:
try {
  await signInWithMicrosoft();
} catch (e, stack) {
  setState(() => _error = SocialSignInError(
    message: "We couldn't sign you in. Please try again.",
    detail: '$e\n$stack',
  ));
}
```

> **Brand compliance:** This package does not bundle provider logos — they are trademarked
> assets that cannot be redistributed in an open-source package. Obtain them from each provider's
> branding guidelines
> ([Google](https://developers.google.com/identity/branding-guidelines),
> [Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)).

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

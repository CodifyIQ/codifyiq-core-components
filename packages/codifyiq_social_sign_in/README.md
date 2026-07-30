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
* An optional **email magic-link** option: a "Continue with email" button that reveals an
  inline form with a "check your inbox" confirmation and resend cooldown (see
  [Magic-link sign-in](#magic-link-sign-in)).
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

## Magic-link sign-in

Add `MagicLinkButton` to `signInButtons` with an `onSubmitEmail` callback.
Tapping it reveals an inline form. On submission, a confirmation screen appears
with a resend option (`resendCooldown` is configurable; `onResend` defaults to
`onSubmitEmail`).

```dart
SocialSignInScreen(
  signInButtons: [
    SocialSignInButton(icon: googleLogo, label: 'Continue with Google', onPressed: _google),
    MagicLinkButton(
      onSubmitEmail: (email) => _sendMagicLink(email),
    ),
  ],
);

```

`MagicLinkForm` is also exported for standalone use outside `SocialSignInScreen`.

> **Backend Security:** Always return `202 Success` on email submission to
> prevent account enumeration.

### Code fallback

Providing `onSubmitCode` adds a fallback field for short codes included in the
email — useful when link clicks fail due to cross-device access or email scanner
pre-fetching.

```dart
MagicLinkButton(
  onSubmitEmail: (email) => _sendMagicLink(email),
  onSubmitCode: (code) => _verifyCode(code),
  codeLength: 6,
  codeHelperText: 'The code expires in 15 minutes.',
);
```

The callback receives only the code (pasted separators ` `/`-` are auto-stripped),
and thrown exceptions display inline errors. `MagicLinkCodeField` is also
available as a standalone component.

### Using Firebase

Firebase Auth natively handles email-link sign-in:

```dart
MagicLinkButton(
  onSubmitEmail: (email) async {
    await prefs.setString('pendingMagicLinkEmail', email);
    await FirebaseAuth.instance.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: 'https://example.com/verify',
        handleCodeInApp: true,
        androidPackageName: 'com.example.app',
        iOSBundleId: 'com.example.app',
      ),
    );
  },
);

// Deep-link verify handler:
if (auth.isSignInWithEmailLink(link)) {
  final credential = await auth.signInWithEmailLink(
    email: storedEmail,
    emailLink: link,
  );
}
```

### Deep linking

Route magic links to a verified path using standard HTTPS App Links (Android) or
Universal Links (iOS). Do not use Firebase Dynamic Links, as they are sunset.

### Registration completion

Authentication completes at your `/verify` deep-link route outside this widget's
lifecycle. Gate onboarding via router-level redirects based on server-side
profile completeness rather than inline widget callbacks.

> **Brand compliance:** This package does not bundle provider logos — they are trademarked
> assets that cannot be redistributed in an open-source package. Obtain them from each provider's
> branding guidelines
> ([Google](https://developers.google.com/identity/branding-guidelines),
> [Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)).

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

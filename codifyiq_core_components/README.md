# CodifyIQ Common Components

[![License](https://img.shields.io/github/license/mashape/apistatus.svg)](https://opensource.org/licenses/mit)

**CodifyIQ Common Components** is an open-source Flutter library designed to accelerate mobile and 
web application development by providing reusable, customizable, and production-ready UI components. 
Built with flexibility and performance in mind, this library empowers developers to quickly 
integrate common functionalities into their Flutter projects while maintaining full control over 
customization and long-term maintenance.

This library is developed by [CodifyIQ](https://codifyiq.com) to streamline development workflows, 
reduce boilerplate code, and ensure high-quality, maintainable solutions. The components are 
designed to be modular, extensible, and free from proprietary dependencies, allowing developers to 
adapt and maintain their projects independently.

## Features

- **Reusable UI Components**: Pre-built, customizable widgets to speed up development.
- **Open Source**: Licensed under MIT for maximum flexibility and community contribution.
- **Cross-Platform**: Compatible with Flutter for iOS, Android, web, and desktop applications.
- **Extensible Design**: Built with customization in mind to fit a wide range of use cases.
- **Well-Documented**: Comprehensive documentation and examples for each component.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  codifyiq_core_components: ^0.7.0
```

## Widgets

### `BrightnessButton`

The `BrightnessButton` is a simple wrapper around AdaptiveTheme to toggle light/dark mode. It can be 
combined with all other widgets in this library.

### `TermsAndConditionsWidget`

The `TermsAndConditionsWidget` provides a standardized way to display terms and conditions to users and require them to accept before proceeding. It features:

*   Scrollable Markdown view for the terms.
*   A checkbox for acceptance.
*   The checkbox is enabled only when the content is non-scrollable or the user has scrolled to the very end of the terms.
*   Customizable terms content and an `onAccepted` callback.
*   Defaults to `ipsom lorem` while your legal team works on exact language.

### `AiProgressIndicator`

The `AiProgressIndicator` provides a subtle visual cue that an AI-enabled feature is being executed,
distinguishing it from standard loading states. It combines a circular progress indicator with a
shimmer effect that sweeps across the widget. Colors are derived from the app's theme by default
(`onSurface`, `primary`, `tertiary`), but can be tailored by wrapping the widget in a custom `Theme`
or providing a `textStyle` override. It features:

*   A required `text` message displayed alongside the progress indicator.
*   A multi-color shimmer gradient derived from the app's theme, customizable via `ThemeData`/`ColorScheme`.
*   Configurable `shimmerPeriod` to control the speed of the shimmer sweep.
*   Configurable `shimmerIntensity` (0.0–1.0) to boost highlight color contrast — brightness-aware for both light and dark modes.
*   An optional `backgroundColor` to increase contrast against certain surfaces.
*   An optional `textStyle` override for the displayed text.
*   An optional `showProgressIndicator` flag (defaults to `true`) to hide the circular progress indicator and show only shimmer text.

### `ErrorRetryWidget`

The `ErrorRetryWidget` provides a standardized way to display errors that can be retried. It features:

*   A required `errorMessage` value that will be displayed.
*   A retry button.
*   Customizable retry logic via an `onRetry` callback.

### `SocialSignInScreen`

The `SocialSignInScreen` provides a complete sign-in screen layout with logo, tagline, social
sign-in buttons, error display, and footer. It is purely presentational — consuming apps inject
their own branding, buttons, and authentication callbacks. It features:

*   A customizable logo, tagline, sign-in prompt, and footer.
*   An error message container styled from the app's theme.
*   A built-in processing state that replaces sign-in buttons with a progress indicator during
    authentication, preventing duplicate taps.
*   `SocialSignInButton` — a companion widget for consistent button styling with icon and label.
*   An optional **reviewer login easter egg** for app store submissions: tapping the logo a
    configurable number of times (default 5) reveals a built-in email/password form for app store
    reviewers who don't have social accounts. Just provide an `onReviewerSignIn` callback:

    ```dart
    SocialSignInScreen(
      reviewerLoginEnabled: true,
      onReviewerSignIn: (email, password) => _signIn(email, password),
      // ...
    )
    ```

    For a fully custom reviewer UI, pass a widget via `reviewerLoginContent` instead to override
    the built-in form.

> **Brand compliance:** Social sign-in providers require their official logos with brand-compliant
> colors. This library does not bundle provider logos, as they are trademarked assets that cannot
> be redistributed in an open-source package. Obtain them directly from each provider:
> * **Google:** [Google Identity Branding Guidelines](https://developers.google.com/identity/branding-guidelines)
> * **Apple:** [Apple Design Resources](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)

### Examples
You can find sample code in the `example` directory as well as more details in the
[Examples README](./example/README.md) for details.

## Works with

| Task | Guide |
|------|-------|
| Firebase auth (Flutter) — sign-in flows, Riverpod wiring, GoRouter guards | [codifyiq_firebase_authentication README](https://github.com/CodifyIQ/codifyiq-firebase-authentication/blob/dev/codifyiq_firebase_authentication/README.md) |
| Firebase JWT verification (FastAPI backend) | [fastapi-cloudauth-lenient README](https://github.com/CodifyIQ/fastapi-cloudauth-lenient#readme) |

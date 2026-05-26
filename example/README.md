[[Return to Main Documentation]](../README.md)

## Examples

You can see running examples of the widgets by:
 1. Install the dependencies:
 ```bash
 flutter pub get
 ```
 2. Run the example dart file:
 ```bash
 flutter run -t ./example/main.dart -d chrome
 ```

### `BrightnessButton`
A self contained button to activate a change in brightness (light/dark mode) using the 
[AdaptiveTheme library](https://pub.dev/packages/adaptive_theme).  Please see AdaptiveTheme 
documentation for how to configure it your codebase. Alternatively, see how [main.dart](./main.dart) 
is leveraging this library.  

### `TermsAndConditionsWidget`
Please see [terms_and_conditions_widget_example.dart](./terms_and_conditions_widget_example.dart) 
for usage details around the `TermsAndConditionsWidget`.

### `AiProgressIndicator`
A subtle progress indicator intended to communicate that an AI-enabled feature is being executed.
It combines a circular progress indicator with a shimmer effect. Colors are derived from the app's
theme by default but can be tailored via a custom `Theme`/`ColorScheme` or `textStyle` override.
Supports configurable sweep speed, brightness-aware color intensity boost, an optional background
color for increased visibility, and the ability to hide the circular progress indicator.

Please see [ai_progress_indicator_example.dart](./ai_progress_indicator_example.dart)
for usage details around the `AiProgressIndicator`.

### `ErrorRetryWidget`
A widget for displaying a standardized error message with a "Retry" button. This
is useful for handling network failures or other recoverable errors.

Please see [error_retry_widget_example.dart](./error_retry_widget_example.dart)
for usage details around the `ErrorRetryWidget`.

### `SocialSignInScreen`
A complete sign-in screen layout with logo, tagline, social sign-in buttons, error display, and
footer. Includes an optional reviewer login easter egg — tap the logo 5 times to reveal an
email/password form for app store reviewers. The example demonstrates a simulated sign-in
handshake with processing state and placeholder icons for Google and Apple.

Please see [social_sign_in_screen_example.dart](./social_sign_in_screen_example.dart)
for usage details around the `SocialSignInScreen`.


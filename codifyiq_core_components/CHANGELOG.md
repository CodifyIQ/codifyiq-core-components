# Changelog

## 0.8.0
* New widget: `ChatWidget` — reusable conversational chat surface backed by [flutter_chat_ui](https://pub.dev/packages/flutter_chat_ui)
  * Pluggable `ChatBackend` interface so consumers can wire in any chat service (REST, streaming, local LLM) without coupling to a specific state-management library
  * Built-in suggestion chips, error banner, and composer with thinking-state hint
  * Optional `initialMessage` to auto-send a first user turn after the greeting (for "explain this" flows)
  * `onMutations` callback so the host can refresh dependent state when a turn reports side effects
  * Theme-aware message bubbles, agent avatar, and configurable user/agent display names and identifiers

## 0.7.0
* New widget: `SocialSignInScreen` — customizable sign-in screen with logo, tagline, social buttons, error display, and footer
  * Optional reviewer login easter egg for app store submissions — tap the logo to reveal an email/password form for reviewers
  * Built-in processing state replaces sign-in buttons with a progress indicator during authentication, preventing duplicate taps
* New widget: `SocialSignInButton` — consistent button styling for social sign-in providers

## 0.6.0
* New widget: `AiProgressIndicator` — a subtle shimmer progress indicator to visually communicate that an AI-enabled feature is being executed
  * Configurable shimmer sweep speed and brightness-aware color intensity
  * Optional background color for increased visibility
  * Optional ability to hide the circular progress indicator for a text-only shimmer
  * Theme-derived colors by default, with full customization support via `Theme`/`ColorScheme` or `textStyle`
* Added package barrel file — import all widgets with `import 'package:codifyiq_core_components/codifyiq_core_components.dart'`
* Reduced transitive dependency footprint for consumers

## 0.5.0 
* Fixed static analysis warning

## 0.4.0 
* Added `BrightnessButton`
* Refactored examples to work with light/dark mode

## 0.3.0
* Update terms and conditions widget for more consistent formatting

## 0.2.0
* Added basic retry widget
* Added demo page for previewing the widgets

## 0.1.2
* Continuing to refine cleanup and publishing

## 0.1.1
* Cleanup activities; changed Markdown flavor to be `gpt_markdown`

## 0.1.0
* Initial release of a generic terms and conditions widget

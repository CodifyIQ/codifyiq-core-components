# Changelog

## 0.7.0
* New widget set: `NotificationBellButton`, `NotificationCenterPanel`, `NotificationCenterPage`, and `NotificationCenterController` — a Play Store-style notification center for tracking long-running, user-initiated tasks
  * App-bar bell with a Material 3 unread badge that opens an anchored dropdown panel
  * Items are grouped into **In progress**, **Failed**, and **Completed** sections with linear progress bars on running rows and status icons on finished rows
  * Per-item tap callback and optional labeled trailing action (e.g. "Open", "Retry") for completed rows
  * Individual dismiss plus "Clear completed" bulk action; running items persist until explicitly completed or failed
  * Adaptive presentation — opens an anchored dropdown on wide viewports and pushes a full-screen `NotificationCenterPage` (with back button) on narrow/mobile viewports (configurable breakpoint, default 600px)
  * Optional `NotificationCenterScope` `InheritedNotifier` exposes the controller ambiently so any descendant widget can post updates without prop-drilling
  * UI-only: consumers wire the controller to their own task layer (HTTP, isolates, platform background workers, etc.)
* `BrightnessButton` now renders its dropdown as a Material 3 surface (rounded corners, elevation, surface tint) and accepts `menuAlignmentOffset` / `menuScreenEdgeInset` to control drop distance and the gap from the trailing viewport edge — matching the new `NotificationBellButton` styling
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

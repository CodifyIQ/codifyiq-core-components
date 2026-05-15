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

### `NotificationBellButton` / Notification Center

A Play Store-style notification center for tracking long-running, user-initiated tasks (uploads,
downloads, multi-step background work) without blocking the UI. The widget set includes:

*   `NotificationBellButton` — an `AppBar` action with a stoplight-coded Material 3 badge (see
    "Bell badge rules" below). Opens an anchored dropdown panel on wide viewports and pushes a
    full-screen `NotificationCenterPage` (with back button) on narrow/mobile viewports. The
    breakpoint, panel size, drop offset, and trailing edge inset are all configurable.
*   `NotificationCenterController` — a `ChangeNotifier` exposing `start` / `updateProgress` /
    `complete` / `fail` / `dismiss` / `clearCompleted` / `clearAll` / `markAllSeen`. Consumers
    drive the controller from their own task layer (HTTP, isolates, platform workers) — the widget
    is UI-only and does not perform background work.
*   `NotificationCenterPanel` / `NotificationCenterPage` — list view rendering three sections
    (**In progress**, **Failed**, **Completed**) with progress bars on running rows, status icons,
    optional `Open` / `Retry` actions, individual dismiss, and a bulk "Clear completed" header
    action.
*   `NotificationCenterScope` — an `InheritedNotifier` for ambient controller lookup so descendant
    widgets can post updates without prop-drilling.

```dart
final controller = NotificationCenterController();

// Anywhere in your task layer:
controller.start(id: 'job-1', title: 'Uploading invoice.pdf', progress: 0);
controller.updateProgress('job-1', progress: 0.42);
controller.complete(
  'job-1',
  description: 'Saved to Documents/invoice.pdf',
  action: NotificationItemAction(label: 'Open', onPressed: openFile),
);

// In your AppBar:
AppBar(actions: [NotificationBellButton(controller: controller)]);
```

#### Bell badge rules

The bell is a stoplight, not a count. Color and label are derived from the controller's
aggregate state, with the bell icon swapping to a filled variant whenever items are tracked
(so state is conveyed by shape as well as color — WCAG 1.4.1).

**Status priority** (highest to lowest): error → running → success → none. A single unseen
failure beats any in-flight work, so a regression is never hidden behind an in-progress
indicator.

**Badge label**:

| State   | Color | Label                                                                                                |
|---------|-------|------------------------------------------------------------------------------------------------------|
| running | amber | dot — never a count (running is ambient state, the count isn't actionable)                           |
| success | green | count of unseen successes (always homogeneous: success only wins when no running and no unseen errors) |
| error   | red   | count of unseen failures, **or** a `!` glyph when an unseen failure coexists with running work       |

**Quiet semantics**: success and error are notification *events* gated by `seen` — opening the
panel marks items seen and the bell quiets if nothing else is running. Running is current
*state*, not gated by `seen`, so the bell stays lit (amber dot) while work is in flight even
after the user has peeked. A later transition (e.g. running → error) re-lights the bell.

Defaults: amber `Colors.amber.shade700`, green `Colors.green.shade600`, red
`colorScheme.error`. Override per-instance via `runningColor`, `successColor`, `errorColor`,
and swap the active-state icon via `activeIcon`.

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

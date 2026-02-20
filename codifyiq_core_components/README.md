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
  codifyiq_common_components: ^0.1.0
  
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

### Examples
You can find sample code in the `example` directory as well as more details in the 
[Examples README](./example/README.md) for details.
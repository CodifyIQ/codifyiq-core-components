# codifyiq_brightness_button

[![pub package](https://img.shields.io/pub/v/codifyiq_brightness_button.svg)](https://pub.dev/packages/codifyiq_brightness_button)

A simple wrapper around [AdaptiveTheme](https://pub.dev/packages/adaptive_theme) to toggle
between Light, Dark, and System brightness modes. Drop it into an `AppBar` or settings screen.

## Installation

```yaml
dependencies:
  codifyiq_brightness_button: ^1.0.0
```

## Usage

```dart
import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';

AppBar(actions: const [BrightnessButton()]);
```

Your app must be wrapped in `AdaptiveTheme` (see the
[adaptive_theme setup](https://pub.dev/packages/adaptive_theme)) for the toggle to take effect.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

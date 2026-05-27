# codifyiq_ai_progress_indicator

[![pub package](https://img.shields.io/pub/v/codifyiq_ai_progress_indicator.svg)](https://pub.dev/packages/codifyiq_ai_progress_indicator)

A subtle visual cue that an AI-enabled feature is running, distinguishing it from standard
loading states. It combines a circular progress indicator with a shimmer effect that sweeps
across the widget. Colors are derived from the app's theme by default (`onSurface`, `primary`,
`tertiary`) and can be tailored via a custom `Theme` or `textStyle`.

## Features

* A required `text` message displayed alongside the progress indicator.
* A multi-color shimmer gradient derived from `ThemeData` / `ColorScheme`.
* Configurable `shimmerPeriod` (sweep speed) and `shimmerIntensity` (0.0–1.0, brightness-aware).
* Optional `backgroundColor`, `textStyle`, and `showProgressIndicator` flag.

## Installation

```yaml
dependencies:
  codifyiq_ai_progress_indicator: ^1.0.0
```

## Usage

```dart
import 'package:codifyiq_ai_progress_indicator/codifyiq_ai_progress_indicator.dart';

const AiProgressIndicator(text: 'Generating summary…');
```

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

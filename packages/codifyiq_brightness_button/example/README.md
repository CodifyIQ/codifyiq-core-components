# codifyiq_brightness_button example

The app must be wrapped in `AdaptiveTheme` for the toggle to take effect.

```dart
import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:flutter/material.dart';

AppBar buildAppBar() {
  return AppBar(
    title: const Text('Settings'),
    actions: const [BrightnessButton()],
  );
}
```

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

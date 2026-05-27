# codifyiq_terms_and_conditions

[![pub package](https://img.shields.io/pub/v/codifyiq_terms_and_conditions.svg)](https://pub.dev/packages/codifyiq_terms_and_conditions)

A standardized way to display terms and conditions and require acceptance before proceeding.

## Features

* Scrollable Markdown view for the terms (rendered with [`gpt_markdown`](https://pub.dev/packages/gpt_markdown)).
* An acceptance checkbox, enabled only once the content is non-scrollable or the user has
  scrolled to the very end.
* Customizable terms content and an `onAccepted` callback.
* Defaults to placeholder text while your legal team finalizes the language.

## Installation

```yaml
dependencies:
  codifyiq_terms_and_conditions: ^1.0.0
```

## Usage

```dart
import 'package:codifyiq_terms_and_conditions/codifyiq_terms_and_conditions.dart';

TermsAndConditionsWidget(
  onAccepted: () => Navigator.of(context).pop(true),
);
```

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)

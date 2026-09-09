# codifyiq_terms_and_conditions example

```dart
import 'package:codifyiq_terms_and_conditions/codifyiq_terms_and_conditions.dart';
import 'package:flutter/material.dart';

Widget buildTerms(BuildContext context) {
  return TermsAndConditionsWidget(
    headerText: 'Terms of Service',
    onAccepted: () => Navigator.of(context).pop(true),
  );
}
```

The acceptance button is disabled until the terms are scrolled to the end, and
whenever `onAccepted` is null. While the acceptance is being recorded, set
`isProcessing` to disable the button and show a progress indicator:

```dart
TermsAndConditionsWidget(
  isProcessing: _isRecording,
  onAccepted: _recordAcceptance,
);
```

Its two labels default to `'Read to accept'` and `'Accept'`, and can be replaced
to localize them or to use your own assent wording:

```dart
TermsAndConditionsWidget(
  readPromptLabel: 'Lire pour accepter',
  acceptLabel: 'Accepter',
  onAccepted: _recordAcceptance,
);
```

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

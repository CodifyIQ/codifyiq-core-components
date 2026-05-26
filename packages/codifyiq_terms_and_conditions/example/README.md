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

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

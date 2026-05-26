# codifyiq_ai_progress_indicator example

```dart
import 'package:codifyiq_ai_progress_indicator/codifyiq_ai_progress_indicator.dart';
import 'package:flutter/material.dart';

class GeneratingView extends StatelessWidget {
  const GeneratingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AiProgressIndicator(
        text: 'Generating summary…',
        shimmerIntensity: 0.4,
      ),
    );
  }
}
```

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

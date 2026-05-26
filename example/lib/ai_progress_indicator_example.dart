import 'package:codifyiq_ai_progress_indicator/codifyiq_ai_progress_indicator.dart';
import 'package:flutter/material.dart';

/// An example page that demonstrates the usage of the [AiProgressIndicator].
///
/// This widget displays a screen with the [AiProgressIndicator] centered,
/// showing how an AI-enabled loading state looks to the user.
class AiProgressIndicatorExample extends StatelessWidget {
  /// Creates an instance of [AiProgressIndicatorExample].
  const AiProgressIndicatorExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Progress Indicator Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Default — theme colors, no background',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const AiProgressIndicator(text: 'Generating AI response...'),
            const SizedBox(height: 32),
            Text(
              'With background — adds contrast behind the shimmer',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AiProgressIndicator(
              text: 'Generating AI response...',
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 32),
            Text(
              'High intensity + slow — boosted colors, 2.5s sweep',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AiProgressIndicator(
              text: 'Generating AI response...',
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              shimmerIntensity: 0.8,
              shimmerPeriod: const Duration(milliseconds: 2500),
            ),
            const SizedBox(height: 32),
            Text(
              'Text only — no progress indicator',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AiProgressIndicator(
              text: 'Thinking...',
              showProgressIndicator: false,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
      ),
    );
  }
}

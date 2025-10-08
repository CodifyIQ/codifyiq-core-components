import 'package:flutter/material.dart';

/// A reusable widget for displaying an error message and a retry button.
///
/// This widget is useful for handling error states in the UI, providing the
/// user with feedback and an option to perform the action again.
class ErrorRetryWidget extends StatelessWidget {
  /// The error message to be displayed to the user.
  final String errorMessage;

  /// The callback function to be executed when the user taps the retry button.
  final VoidCallback onRetry;

  /// Creates an [ErrorRetryWidget].
  const ErrorRetryWidget({
    Key? key,
    required this.errorMessage,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48.0),
          const SizedBox(height: 16.0),
          Text(
            errorMessage,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              textStyle: theme.textTheme.labelLarge,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

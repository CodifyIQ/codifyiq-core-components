import 'package:codifyiq_core_components/widgets/error_retry_widget.dart';
import 'package:flutter/material.dart';

/// An example page that demonstrates the usage of the [ErrorRetryWidget].
///
/// This stateful widget displays a screen with an app bar and
/// the [ErrorRetryWidget] in its body. It provides a callback
/// function that is triggered when the retry button is selected.
class ErrorRetryWidgetExample extends StatefulWidget {
  /// Creates an instance of [ErrorRetryWidgetExample].
  ///
  /// The [key] parameter is optional and is used to control how one widget
  /// replaces another widget in the tree.
  const ErrorRetryWidgetExample({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ErrorRetryWidgetExampleState createState() =>
      _ErrorRetryWidgetExampleState();
}

/// The state for the [ErrorRetryWidgetExample] widget.
///
/// This class manages the state of the example page, including the UI
/// and the logic for handling the acceptance of terms and conditions.
class _ErrorRetryWidgetExampleState extends State<ErrorRetryWidgetExample> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Error Retry Example')),
      body: ErrorRetryWidget(errorMessage: 'The error message I want to display', onRetry: _onRetry),
    );
  }

  /// Callback function invoked when the terms and conditions are accepted.
  ///
  /// This is the probably just the function that was originally being called in your codebase
  void _onRetry() {
    // Example: Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The action to retry triggered!')),
    );

    debugPrint("Retry initiated by the user.");
  }
}

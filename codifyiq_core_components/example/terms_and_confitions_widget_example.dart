import 'package:codifyiq_core_components/widgets/terms_and_conditions_widget.dart';
import 'package:flutter/material.dart';

/// An example page that demonstrates the usage of the [TermsAndConditionsWidget].
///
/// This stateful widget displays a screen with an app bar and
/// the [TermsAndConditionsWidget] in its body. It provides a callback
/// function that is triggered when the terms and conditions are accepted.
class TermsAndConditionsExample extends StatefulWidget {
  /// Creates an instance of [TermsAndConditionsExample].
  ///
  /// The [key] parameter is optional and is used to control how one widget
  /// replaces another widget in the tree.
  const TermsAndConditionsExample({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TermsAndConditionsExampleState createState() =>
      _TermsAndConditionsExampleState();
}

/// The state for the [TermsAndConditionsExample] widget.
///
/// This class manages the state of the example page, including the UI
/// and the logic for handling the acceptance of terms and conditions.
class _TermsAndConditionsExampleState extends State<TermsAndConditionsExample> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Terms and Conditions Example')),
      body: TermsAndConditionsWidget(onAccepted: _onAccepted),
    );
  }

  /// Callback function invoked when the terms and conditions are accepted.
  ///
  /// Developers should implement the desired actions here, such as:
  /// - Persisting the acceptance status and any related metadata (e.g., timestamp).
  /// - Navigating the user to the main part of the application (e.g., home page).
  void _onAccepted() {
    // Example: Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terms and Conditions Accepted!')),
    );

    // TODO: Implement actual acceptance logic:
    //  * persist acceptance and related metadata
    //  * navigate to home page or similar location
    // For example:
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.setBool('termsAccepted', true);
    // Navigator.of(context).pushReplacementNamed('/home');
    debugPrint("Terms and conditions accepted by the user.");
  }
}

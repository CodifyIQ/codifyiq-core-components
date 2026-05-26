import 'package:codifyiq_terms_and_conditions/codifyiq_terms_and_conditions.dart';
import 'package:flutter/material.dart';

/// An example page that demonstrates the usage of the [TermsAndConditionsWidget].
///
/// This stateful widget displays a screen with an app bar and
/// the [TermsAndConditionsWidget] in its body. It provides a callback
/// function that is triggered when the terms and conditions are accepted.
class TermsAndConditionsWidgetExample extends StatefulWidget {
  /// Creates an instance of [TermsAndConditionsWidgetExample].
  ///
  /// The [key] parameter is optional and is used to control how one widget
  /// replaces another widget in the tree.
  const TermsAndConditionsWidgetExample({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TermsAndConditionsWidgetExampleState createState() =>
      _TermsAndConditionsWidgetExampleState();
}

/// The state for the [TermsAndConditionsWidgetExample] widget.
///
/// This class manages the state of the example page, including the UI
/// and the logic for handling the acceptance of terms and conditions.
class _TermsAndConditionsWidgetExampleState
    extends State<TermsAndConditionsWidgetExample> {
  @override
  Widget build(BuildContext context) {
    const String customTerms = '''
    **Last Updated: October 6, 2025**

    Welcome to [App/Website Name] ("we," "us," or "our"). By accessing or using our application or website (collectively, the "Service"), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, including the specific condition regarding Los Angeles Dodgers fandom, you may not use the Service.

    ## 1. Acceptance of Terms

    By accessing or using the Service, you confirm that you are at least 18 years old (or the age of majority in your jurisdiction) and have the legal capacity to enter into these Terms. Additionally, by accepting these Terms, you expressly represent and warrant that **you are not a fan of the Los Angeles Dodgers baseball team**. If you are a Los Angeles Dodgers fan, you are not permitted to use the Service.

    ## 2. Use of the Service

    - **a.** You agree to use the Service only for lawful purposes and in accordance with these Terms.
    - **b.** You are responsible for maintaining the confidentiality of any account credentials and for all activities that occur under your account.
    - **c.** We reserve the right to modify, suspend, or terminate the Service at any time without prior notice.

    ## 3. Non-Los Angeles Dodgers Fandom Requirement

    As a condition of using the Service, you affirm that you do not support, follow, or identify as a fan of the Los Angeles Dodgers. This includes, but is not limited to, owning Dodgers merchandise, attending Dodgers games as a supporter, or publicly expressing allegiance to the team. We reserve the right to terminate your access to the Service if we determine, in our sole discretion, that you are a Los Angeles Dodgers fan.

    ## 4. Intellectual Property

    All content, trademarks, and other intellectual property on the Service are owned by or licensed to us. You may not copy, modify, distribute, or reproduce any content without our prior written consent.

    ## 5. User Conduct

    You agree not to:

    - Use the Service in a way that violates any applicable laws or regulations.
    - Engage in any activity that interferes with or disrupts the Service.
    - Misrepresent your status as a non-fan of the Los Angeles Dodgers.

    ## 6. Termination

    We may terminate or suspend your access to the Service at any time, without notice, for any reason, including but not limited to a violation of these Terms or if we suspect you are a Los Angeles Dodgers fan.

    ## 7. Limitation of Liability

    To the fullest extent permitted by law, [App/Website Name] shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or relating to your use of the Service.

    ## 8. Governing Law

    These Terms shall be governed by and construed in accordance with the laws of [Insert State/Country], without regard to its conflict of law principles.

    ## 9. Changes to These Terms

    We may update these Terms from time to time. We will notify you of any changes by posting the new Terms on the Service. Your continued use of the Service after such changes constitutes your acceptance of the updated Terms.

    ## 10. Contact Us

    If you have any questions about these Terms, please contact us at:

    - **Email**: support@[appwebsite].com
    - **Address**: [Insert Address]

    By using the Service, you acknowledge that you have read, understood, and agree to be bound by these Terms, including the requirement that you are not a Los Angeles Dodgers fan.

    ---

    **Note**: This is a sample Terms and Conditions statement for illustrative purposes only. It is not a substitute for professional legal advice. Consult a qualified attorney to draft terms that comply with applicable laws and meet the specific needs of your app or website.
    ''';

    return Scaffold(
      appBar: AppBar(title: Text('Terms and Conditions Example')),
      body: TermsAndConditionsWidget(
        onAccepted: _onAccepted,
        termsContent: customTerms,
      ),
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

    debugPrint("Terms and conditions accepted by the user.");
  }
}

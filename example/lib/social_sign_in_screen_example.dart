import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:codifyiq_social_sign_in/codifyiq_social_sign_in.dart';
import 'package:flutter/material.dart';

/// An example page that demonstrates the usage of [SocialSignInScreen].
///
/// Renders the sign-in screen with placeholder branding and up to three
/// social sign-in buttons (Google, Apple, and Microsoft Office 365). Each
/// provider can be independently toggled on or off via the app-bar overflow
/// menu — Google and Apple are enabled by default; Microsoft is disabled by
/// default in the library, but active in this examples as an optional
/// enterprise provider behind a feature flag.
///
/// The reviewer login easter egg is enabled (tap the logo 5 times to reveal
/// it). Tapping any social button simulates a login handshake by enabling
/// the processing state for a few seconds.
///
/// Microsoft sign-in deliberately fails with a raw, backend-style error to
/// demonstrate [SocialSignInError]: the user sees only a friendly message,
/// while the verbose technical detail is captured via `onError` (logged to
/// the console here) instead of being shown on screen.
class SocialSignInScreenExample extends StatefulWidget {
  /// Creates an instance of [SocialSignInScreenExample].
  const SocialSignInScreenExample({super.key});

  @override
  State<SocialSignInScreenExample> createState() =>
      _SocialSignInScreenExampleState();
}

class _SocialSignInScreenExampleState extends State<SocialSignInScreenExample> {
  bool _isProcessing = false;
  bool _googleEnabled = true;
  bool _appleEnabled = true;
  bool _microsoftEnabled = true;
  SocialSignInError? _error;

  void _simulateSignIn(String provider) {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    // Simulate a multi-second authentication handshake.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      // Microsoft fails to demonstrate user-safe error handling.
      if (provider == 'Microsoft') {
        setState(() {
          _isProcessing = false;
          _error = const SocialSignInError(
            message: "We couldn't sign you in. Please try again.",
            detail:
                'Sign-in failed: {(openid, profile, "offline_access")} are '
                'reserved scopes and may not be specified in the acquire '
                'token call.',
          );
        });
        return;
      }

      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$provider authentication complete (simulated)'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SocialSignInScreen(
      appBar: AppBar(
        title: const Text('Social Sign-In Screen Example'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Enabled providers',
            icon: const Icon(Icons.tune),
            onSelected: (value) => setState(() {
              switch (value) {
                case 'google':
                  _googleEnabled = !_googleEnabled;
                case 'apple':
                  _appleEnabled = !_appleEnabled;
                case 'microsoft':
                  _microsoftEnabled = !_microsoftEnabled;
              }
            }),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'google',
                checked: _googleEnabled,
                child: const Text('Google'),
              ),
              CheckedPopupMenuItem(
                value: 'apple',
                checked: _appleEnabled,
                child: const Text('Apple'),
              ),
              CheckedPopupMenuItem(
                value: 'microsoft',
                checked: _microsoftEnabled,
                child: const Text('Microsoft Office 365'),
              ),
            ],
          ),
          const BrightnessButton(),
        ],
      ),
      logo: const FlutterLogo(size: 120),
      tagline: Text(
        'Empowering developers to build more',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
      isProcessing: _isProcessing,
      error: _error,
      // Capture the verbose technical detail for diagnostics (Crashlytics,
      // Sentry, server logs) — never shown to the user. Here we just print it.
      onError: (error) =>
          debugPrint('Sign-in error captured: ${error.detail}'),
      signInButtons: [
        // Each provider button ships with a Material Icons placeholder glyph
        // suitable for prototyping. In production, override `icon:` with the
        // official brand asset — e.g.:
        //   GoogleSignInButton(
        //     icon: SvgPicture.asset('assets/google-logo.svg', width: 18, height: 18),
        //     onPressed: ...,
        //   )
        // See each widget's dartdoc for links to the provider's branding
        // guidelines.
        if (_googleEnabled)
          GoogleSignInButton(onPressed: () => _simulateSignIn('Google')),
        if (_appleEnabled)
          AppleSignInButton(onPressed: () => _simulateSignIn('Apple')),
        if (_microsoftEnabled)
          MicrosoftSignInButton(onPressed: () => _simulateSignIn('Microsoft')),
      ],
      reviewerLoginEnabled: true,
      onReviewerSignIn: (email, password) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reviewer sign-in: $email')));
      },
      footer: Text(
        '© 2025-2026 Vandelay Industries. All Rights Reserved.',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

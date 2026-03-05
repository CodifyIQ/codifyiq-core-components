import 'package:codifyiq_core_components/widgets/social_sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// An example page that demonstrates the usage of [SocialSignInScreen].
///
/// This widget displays a sign-in screen with placeholder branding,
/// two social sign-in buttons (Google and Apple), a footer, and the
/// reviewer login easter egg enabled (tap the logo 5 times to reveal it).
class SocialSignInScreenExample extends StatelessWidget {
  /// Creates an instance of [SocialSignInScreenExample].
  const SocialSignInScreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SocialSignInScreen(
      appBar: AppBar(title: const Text('Social Sign-In Screen Example')),
      logo: const FlutterLogo(size: 120),
      tagline: Text(
        'Empowering developers to build more',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
      signInButtons: [
        SocialSignInButton(
          label: 'Continue with Google',
          // Official Google "G" logo — brand colors baked into the SVG,
          // not affected by app theme.
          icon: SvgPicture.asset(
            'example/assets/images/google-logo.svg',
            width: 18,
            height: 18,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Your Google authentication logic would be handled here',
                ),
              ),
            );
          },
        ),
        SocialSignInButton(
          label: 'Continue with Apple',
          // In production, use the official Apple logo asset. Per Apple's
          // guidelines the logo must be black on light backgrounds and
          // white on dark backgrounds — never themed to match the app.
          icon: Icon(
            Icons.apple,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Your Apple authentication logic would be handled here',
                ),
              ),
            );
          },
        ),
      ],
      reviewerLoginEnabled: true,
      onReviewerSignIn: (email, password) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reviewer sign-in: $email')),
        );
      },
      footer: Text(
        '© 2025-2026 Vandelay Industries. All Rights Reserved.',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

/// A generic social sign-in screen layout with optional reviewer login easter egg.
///
/// Provides the common sign-in screen pattern — logo, tagline, sign-in buttons,
/// and optional footer — without any authentication logic or provider-specific
/// dependencies. Consuming apps inject their own branding, buttons, and auth
/// callbacks.
///
/// ## Reviewer Login Easter Egg
///
/// App store reviewers need a way to sign in without social accounts. When
/// [reviewerLoginEnabled] is `true`, tapping the logo [reviewerLoginTapThreshold]
/// times (default 5) reveals an email/password form in place of the social
/// sign-in buttons. The tap counter auto-resets after 5 seconds of inactivity.
///
/// Provide [onReviewerSignIn] to receive the email and password when the
/// reviewer submits the form. For fully custom reviewer UIs, pass a widget
/// via [reviewerLoginContent] instead.
///
/// ## Processing State
///
/// Authentication handshakes can take several seconds. Set [isProcessing] to
/// `true` after a sign-in button is tapped to replace the buttons with a
/// progress indicator and optional [processingMessage]. This prevents
/// duplicate taps and gives the user visual feedback that login is underway.
///
/// ## Usage
///
/// ```dart
/// SocialSignInScreen(
///   logo: Image.asset('assets/logo.png', height: 120),
///   tagline: Text('Welcome back!'),
///   isProcessing: _isSigningIn,
///   signInButtons: [
///     SocialSignInButton(
///       label: 'Continue with Google',
///       icon: SvgPicture.asset('assets/google-logo.svg', width: 18),
///       onPressed: () => _signInWithGoogle(),
///     ),
///   ],
///   reviewerLoginEnabled: true,
///   onReviewerSignIn: (email, password) => _signInWithEmail(email, password),
///   footer: Text('© 2025 My Company'),
/// )
/// ```
class SocialSignInScreen extends StatefulWidget {
  /// Creates a [SocialSignInScreen].
  ///
  /// [logo] is the app logo displayed prominently at the top.
  /// [signInButtons] are the sign-in option widgets displayed below the prompt.
  /// [reviewerLoginEnabled] enables the hidden tap-to-reveal login (default `false`).
  /// [reviewerLoginTapThreshold] is the number of taps needed to reveal it (default `5`).
  /// [onReviewerSignIn] is called with the email and password when the
  /// built-in reviewer form is submitted.
  /// [reviewerLoginContent] overrides the built-in form with a custom widget.
  const SocialSignInScreen({
    super.key,
    required this.logo,
    required this.signInButtons,
    this.tagline,
    this.signInPrompt = 'Sign in or register with:',
    this.errorMessage,
    this.footer,
    this.reviewerLoginEnabled = false,
    this.reviewerLoginTapThreshold = 5,
    this.onReviewerSignIn,
    this.reviewerLoginContent,
    this.reviewerLoginPrompt = 'Reviewer Sign In',
    this.appBar,
    this.isProcessing = false,
    this.processingMessage = 'Signing in…',
  }) : assert(
         !reviewerLoginEnabled ||
             onReviewerSignIn != null ||
             reviewerLoginContent != null,
         'Either onReviewerSignIn or reviewerLoginContent must be provided '
         'when reviewerLoginEnabled is true',
       );

  /// Optional app bar displayed at the top of the screen.
  ///
  /// Useful for adding a back button when this screen is pushed onto a
  /// navigation stack (e.g., in a widget catalog or demo app).
  final PreferredSizeWidget? appBar;

  /// The app logo displayed at the top of the screen.
  ///
  /// When [reviewerLoginEnabled] is `true`, the logo is wrapped in a
  /// [GestureDetector] to capture taps for the easter egg.
  final Widget logo;

  /// Optional tagline or byline displayed below the logo.
  final Widget? tagline;

  /// The sign-in option widgets displayed below the prompt.
  final List<Widget> signInButtons;

  /// Text displayed above the sign-in buttons.
  ///
  /// Defaults to `'Sign in or register with:'`.
  final String signInPrompt;

  /// Optional error message displayed in a themed error container.
  final String? errorMessage;

  /// Optional footer content displayed at the bottom of the screen.
  final Widget? footer;

  /// Whether the reviewer login easter egg is enabled.
  ///
  /// When `true`, tapping the [logo] widget [reviewerLoginTapThreshold] times
  /// reveals [reviewerLoginContent] in place of the social sign-in buttons.
  /// Defaults to `false`.
  final bool reviewerLoginEnabled;

  /// Number of taps on the logo required to reveal the reviewer login.
  ///
  /// The counter auto-resets after 5 seconds of inactivity. Defaults to `5`.
  final int reviewerLoginTapThreshold;

  /// Called with the email and password when the built-in reviewer login
  /// form is submitted.
  ///
  /// When provided (and [reviewerLoginContent] is `null`), the widget renders
  /// a standard email/password form automatically. Only used when
  /// [reviewerLoginEnabled] is `true`.
  final void Function(String email, String password)? onReviewerSignIn;

  /// Optional custom widget displayed when the reviewer login is triggered.
  ///
  /// When provided, this replaces the built-in email/password form entirely.
  /// Only used when [reviewerLoginEnabled] is `true`.
  final Widget? reviewerLoginContent;

  /// Text displayed above the reviewer login content when revealed.
  ///
  /// Defaults to `'Reviewer Sign In'`.
  final String reviewerLoginPrompt;

  /// Whether a sign-in operation is currently in progress.
  ///
  /// When `true`, the sign-in buttons are replaced with a
  /// [CircularProgressIndicator] and [processingMessage]. Use this to
  /// indicate that an authentication handshake is underway after the user
  /// taps a sign-in button.
  final bool isProcessing;

  /// Message displayed below the progress indicator while [isProcessing]
  /// is `true`.
  ///
  /// Defaults to `'Signing in…'`.
  final String processingMessage;

  @override
  State<SocialSignInScreen> createState() => _SocialSignInScreenState();
}

class _SocialSignInScreenState extends State<SocialSignInScreen> {
  int _tapCount = 0;
  bool _isReviewerLoginRevealed = false;
  Timer? _resetTimer;

  static const Duration _resetDuration = Duration(seconds: 5);

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleLogoTap() {
    _resetTimer?.cancel();

    final newCount = _tapCount + 1;
    final isRevealed = newCount >= widget.reviewerLoginTapThreshold;

    setState(() {
      _tapCount = newCount;
      _isReviewerLoginRevealed = isRevealed;
    });

    if (!isRevealed) {
      _resetTimer = Timer(_resetDuration, _resetTapCounter);
    }
  }

  void _resetTapCounter() {
    _resetTimer?.cancel();
    setState(() {
      _tapCount = 0;
      _isReviewerLoginRevealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final logoWidget = widget.reviewerLoginEnabled
        ? GestureDetector(onTap: _handleLogoTap, child: widget.logo)
        : widget.logo;

    return Scaffold(
      appBar: widget.appBar,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              logoWidget,
              if (widget.tagline != null) ...[
                const SizedBox(height: 16),
                widget.tagline!,
              ],
              const SizedBox(height: 32),
              Text(
                _isReviewerLoginRevealed
                    ? widget.reviewerLoginPrompt
                    : widget.signInPrompt,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (widget.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (widget.isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  widget.processingMessage,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (_isReviewerLoginRevealed) ...[
                widget.reviewerLoginContent ??
                    _ReviewerLoginForm(onSignIn: widget.onReviewerSignIn!),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _resetTapCounter,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to social logins'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ] else
                for (int i = 0; i < widget.signInButtons.length; i++) ...[
                  widget.signInButtons[i],
                  if (i < widget.signInButtons.length - 1)
                    const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.footer != null
          ? Padding(padding: const EdgeInsets.all(16), child: widget.footer)
          : null,
    );
  }
}

/// Built-in email/password form for the reviewer login easter egg.
class _ReviewerLoginForm extends StatefulWidget {
  const _ReviewerLoginForm({required this.onSignIn});

  final void Function(String email, String password) onSignIn;

  @override
  State<_ReviewerLoginForm> createState() => _ReviewerLoginFormState();
}

class _ReviewerLoginFormState extends State<_ReviewerLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSignIn(_emailController.text, _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Email is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Password is required'
                  : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Sign In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A convenience widget for consistent social sign-in button styling.
///
/// Renders as a fixed-width [OutlinedButton] with an icon and label, matching
/// the common pattern for social sign-in buttons. Not required — consumers can
/// use any widget in [SocialSignInScreen.signInButtons].
///
/// **Important:** Social sign-in providers require their official logos with
/// brand-compliant colors — do not allow icons to inherit your app's theme
/// colors. This library intentionally does not bundle provider logos, as they
/// are trademarked assets that cannot be redistributed in an open-source
/// package. You must obtain them directly from each provider:
///
/// * **Google:** Download from [Google Identity Branding Guidelines](https://developers.google.com/identity/branding-guidelines)
/// * **Apple:** Download from [Apple Design Resources](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)
///
/// ```dart
/// // Google: official logo SVG with brand colors baked in
/// SocialSignInButton(
///   label: 'Continue with Google',
///   icon: SvgPicture.asset('assets/google-logo.svg', width: 18, height: 18),
///   onPressed: () => _signInWithGoogle(),
/// )
///
/// // Apple: black on light backgrounds, white on dark
/// SocialSignInButton(
///   label: 'Continue with Apple',
///   icon: Icon(Icons.apple,
///     color: Theme.of(context).brightness == Brightness.light
///       ? Colors.black
///       : Colors.white),
///   onPressed: () => _signInWithApple(),
/// )
/// ```
class SocialSignInButton extends StatelessWidget {
  /// Creates a [SocialSignInButton].
  ///
  /// [label] is the button text (e.g., `'Continue with Google'`).
  /// [icon] is the provider icon or logo widget.
  /// [onPressed] is the tap handler; pass `null` to disable the button.
  const SocialSignInButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.style,
    this.width = 300,
  });

  /// The button text (e.g., `'Continue with Google'`).
  final String label;

  /// The provider icon or logo widget.
  final Widget icon;

  /// Tap handler. Pass `null` to disable the button.
  final VoidCallback? onPressed;

  /// Optional style override for the [OutlinedButton].
  final ButtonStyle? style;

  /// The button width. Defaults to `300`.
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
        style: style,
      ),
    );
  }
}

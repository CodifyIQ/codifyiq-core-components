import 'dart:async';

import 'package:flutter/material.dart';

/// A sign-in failure split into a user-safe [message] and the underlying
/// technical [detail].
///
/// Authentication backends often surface diagnostics that are useful for
/// debugging but meaningless — or alarming — to end users, e.g.
/// `"{(openid, profile, "offline_access")} are reserved scopes and may not be
/// specified in the acquire token call"`. Passing such text straight to the
/// screen leaks implementation detail to the user.
///
/// Instead, wrap the failure in a [SocialSignInError]:
/// [SocialSignInScreen] displays only [message] (a short, friendly string),
/// while [detail] — the raw exception, provider error code, or stack trace —
/// is never shown. The detail is instead handed to
/// [SocialSignInScreen.onError] so the host app can capture it in its own
/// diagnostics (Crashlytics, Sentry, server logs).
///
/// ```dart
/// try {
///   await _signInWithMicrosoft();
/// } catch (e, stack) {
///   setState(() => _error = SocialSignInError(detail: '$e\n$stack'));
/// }
/// ```
class SocialSignInError {
  /// Creates a [SocialSignInError].
  ///
  /// [message] is the user-facing, sanitized text shown on screen. Defaults
  /// to a generic retry prompt so callers can omit it and surface only a safe
  /// message by default.
  /// [detail] is the underlying technical cause — captured via
  /// [SocialSignInScreen.onError] but never displayed.
  const SocialSignInError({
    this.message = 'Sign-in failed. Please try again.',
    this.detail,
  });

  /// The user-facing, sanitized message shown in the error container.
  final String message;

  /// The underlying technical detail (exception, provider error code, stack
  /// trace, …).
  ///
  /// Reported to [SocialSignInScreen.onError] for logging but **never**
  /// rendered to the user.
  final Object? detail;
}

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
/// ## Error Handling
///
/// Sign-in failures should never expose raw backend diagnostics to the user.
/// Pass a [SocialSignInError] via [error]: the screen renders only its
/// user-safe [SocialSignInError.message], and reports the technical
/// [SocialSignInError.detail] to [onError] so the host app can log it. See
/// [SocialSignInError] for an example.
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
    this.error,
    this.onError,
    @Deprecated(
      'Use `error` with a SocialSignInError instead, which keeps raw '
      'diagnostics out of the UI and reports them to `onError`. '
      'Will be removed in a future release.',
    )
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

  /// Optional sign-in error displayed in a themed error container.
  ///
  /// Only [SocialSignInError.message] is shown to the user; the technical
  /// [SocialSignInError.detail] is withheld from the UI and reported to
  /// [onError] instead. Set to `null` to clear the error.
  final SocialSignInError? error;

  /// Called once each time a new [error] is presented, with that error.
  ///
  /// Use this to capture the (unredacted) [SocialSignInError.detail] in your
  /// app's diagnostics — Crashlytics, Sentry, structured logs — without ever
  /// surfacing it to the user. Fires after the frame in which the error first
  /// appears; not called for the deprecated [errorMessage].
  final void Function(SocialSignInError error)? onError;

  /// Optional error message displayed in a themed error container.
  ///
  /// Renders verbatim, so it risks exposing raw backend diagnostics to the
  /// user.
  @Deprecated(
    'Use `error` with a SocialSignInError instead, which keeps raw '
    'diagnostics out of the UI and reports them to `onError`. '
    'Will be removed in a future release.',
  )
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
  void initState() {
    super.initState();
    _reportError(widget.error);
  }

  @override
  void didUpdateWidget(SocialSignInScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.error, oldWidget.error)) {
      _reportError(widget.error);
    }
  }

  /// Hands a newly presented [error] to [SocialSignInScreen.onError] after the
  /// current frame, so capturing the detail (which may call `setState` on a
  /// parent) doesn't run during build.
  void _reportError(SocialSignInError? error) {
    if (error == null) return;
    final onError = widget.onError;
    if (onError == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onError(error);
    });
  }

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

    // Resolve the message to display, preferring the structured `error`.
    // The deprecated `errorMessage` is treated as an already-safe message.
    final errorText =
        widget.error?.message ??
        // ignore: deprecated_member_use_from_same_package
        widget.errorMessage;

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
              if (errorText != null) ...[
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
                          errorText,
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
/// For the common providers, prefer the preconfigured wrappers that bake in
/// the brand-mandated label and (where applicable) icon coloring:
/// [GoogleSignInButton], [AppleSignInButton], and [MicrosoftSignInButton].
/// Use [SocialSignInButton] directly only for providers without a wrapper
/// (e.g., Facebook, GitHub, an enterprise IdP) or when you need full control
/// over the label.
///
/// **Important:** Social sign-in providers require their official logos with
/// brand-compliant colors — do not allow icons to inherit your app's theme
/// colors. This library intentionally does not bundle provider logos, as they
/// are trademarked assets that cannot be redistributed in an open-source
/// package. Obtain them directly from each provider's branding guidelines
/// (links in the per-provider wrapper class docs).
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

/// A convenience [SocialSignInButton] preconfigured for Google sign-in.
///
/// Defaults [label] to `'Continue with Google'` and [icon] to a Material
/// Icons placeholder suitable for prototyping. **For production**, replace
/// [icon] with the official multi-colored "G" mark from the
/// [Google Identity Branding Guidelines](https://developers.google.com/identity/branding-guidelines);
/// Google's guidelines require the brand colors be preserved, and the
/// placeholder is not brand-compliant. The official logo is a trademarked
/// asset and cannot be bundled in an open-source package — obtain it
/// directly from Google.
///
/// ```dart
/// GoogleSignInButton(
///   icon: SvgPicture.asset('assets/google-logo.svg', width: 18, height: 18),
///   onPressed: () => _signInWithGoogle(),
/// )
/// ```
class GoogleSignInButton extends StatelessWidget {
  /// Creates a [GoogleSignInButton].
  ///
  /// [onPressed] is the tap handler; pass `null` to disable the button.
  /// [icon] overrides the placeholder Material Icons glyph — replace with
  /// the official Google "G" mark for production (see class docs).
  /// [label] overrides the default `'Continue with Google'` text.
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.icon = const Icon(Icons.g_mobiledata, size: 24),
    this.label = 'Continue with Google',
    this.style,
    this.width = 300,
  });

  /// The Google logo widget. Defaults to a Material Icons placeholder
  /// suitable for prototyping; replace with the official brand asset for
  /// production (see class docs).
  final Widget icon;

  /// Tap handler. Pass `null` to disable the button.
  final VoidCallback? onPressed;

  /// The button text. Defaults to `'Continue with Google'`.
  final String label;

  /// Optional style override for the underlying button.
  final ButtonStyle? style;

  /// The button width. Defaults to `300`.
  final double width;

  @override
  Widget build(BuildContext context) {
    return SocialSignInButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      style: style,
      width: width,
    );
  }
}

/// Background brightness used to resolve the Apple logo color.
///
/// Apple's sign-in guidelines mandate exactly two icon colors — black on
/// light backgrounds, white on dark — so [AppleSignInButton] restricts the
/// override to these two choices rather than accepting an arbitrary [Color].
enum AppleIconBrightness {
  /// Light background — Apple mark must be black.
  light,

  /// Dark background — Apple mark must be white.
  dark,
}

/// A convenience [SocialSignInButton] preconfigured for Apple sign-in.
///
/// Defaults [label] to `'Continue with Apple'`. Per Apple's guidelines the
/// logo must be **black on light backgrounds** and **white on dark
/// backgrounds** — never themed to match the app. This widget enforces that
/// rule by wrapping [icon] in an [IconTheme] whose color is derived from the
/// ambient [Theme.of] brightness (override with [iconBrightness] when the
/// button sits on a background whose brightness differs from the surrounding
/// theme).
///
/// The [IconTheme] mechanism colors `Icon` widgets automatically. For
/// `SvgPicture`, `Image`, or other non-[Icon] logo assets, read the color
/// from `IconTheme.of(context).color` in your icon widget and apply it via
/// the asset's color/`colorFilter` parameter.
///
/// Defaults [icon] to Material's `Icons.apple` glyph, which is suitable for
/// prototyping and is colored automatically by the [IconTheme] wrap. For
/// production, replace it with the official Apple mark from
/// [Apple Design Resources](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)
/// (the Apple logo is a trademarked asset and cannot be bundled in an
/// open-source package).
///
/// ```dart
/// // Defaults — uses Material's Apple glyph.
/// AppleSignInButton(onPressed: () => _signInWithApple())
///
/// // Production — official SVG asset, color read from the IconTheme.
/// AppleSignInButton(
///   icon: Builder(
///     builder: (context) => SvgPicture.asset(
///       'assets/apple-logo.svg',
///       colorFilter: ColorFilter.mode(
///         IconTheme.of(context).color!,
///         BlendMode.srcIn,
///       ),
///     ),
///   ),
///   onPressed: () => _signInWithApple(),
/// )
/// ```
class AppleSignInButton extends StatelessWidget {
  /// Creates an [AppleSignInButton].
  ///
  /// [onPressed] is the tap handler; pass `null` to disable the button.
  /// [icon] overrides the default Material glyph. `Icon` widgets are colored
  /// automatically via [IconTheme]; non-`Icon` assets should read from
  /// `IconTheme.of(context)` themselves (see class docs).
  /// [label] overrides the default `'Continue with Apple'` text.
  /// [iconBrightness] overrides the auto-detected background brightness.
  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.icon = const Icon(Icons.apple),
    this.label = 'Continue with Apple',
    this.iconBrightness,
    this.style,
    this.width = 300,
  });

  /// The Apple logo widget. Defaults to Material's `Icons.apple` glyph;
  /// override for production (see class docs).
  final Widget icon;

  /// Tap handler. Pass `null` to disable the button.
  final VoidCallback? onPressed;

  /// The button text. Defaults to `'Continue with Apple'`.
  final String label;

  /// Overrides the auto-detected background brightness.
  ///
  /// Defaults to the ambient [Theme.of] brightness. Set explicitly when the
  /// button sits on a background whose brightness differs from the
  /// surrounding theme — for example, a dark hero banner inside a light app.
  final AppleIconBrightness? iconBrightness;

  /// Optional style override for the underlying button.
  final ButtonStyle? style;

  /// The button width. Defaults to `300`.
  final double width;

  @override
  Widget build(BuildContext context) {
    final brightness =
        iconBrightness ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppleIconBrightness.dark
            : AppleIconBrightness.light);
    final iconColor = brightness == AppleIconBrightness.light
        ? Colors.black
        : Colors.white;
    return SocialSignInButton(
      label: label,
      icon: IconTheme.merge(
        data: IconThemeData(color: iconColor),
        child: icon,
      ),
      onPressed: onPressed,
      style: style,
      width: width,
    );
  }
}

/// A convenience [SocialSignInButton] preconfigured for Microsoft Office 365
/// sign-in.
///
/// Defaults [label] to `'Continue with Microsoft'` and [icon] to a Material
/// Icons placeholder suitable for prototyping. **For production**, replace
/// [icon] with the official four-square Microsoft mark from the
/// [Microsoft identity branding guidelines](https://learn.microsoft.com/en-us/entra/identity-platform/howto-add-branding-in-apps).
/// The official logo is a trademarked asset and cannot be bundled in an
/// open-source package — obtain it directly from Microsoft.
///
/// ```dart
/// MicrosoftSignInButton(
///   icon: SvgPicture.asset('assets/microsoft-logo.svg', width: 18, height: 18),
///   onPressed: () => _signInWithMicrosoft(),
/// )
/// ```
class MicrosoftSignInButton extends StatelessWidget {
  /// Creates a [MicrosoftSignInButton].
  ///
  /// [onPressed] is the tap handler; pass `null` to disable the button.
  /// [icon] overrides the placeholder Material Icons glyph — replace with
  /// the official Microsoft mark for production (see class docs).
  /// [label] overrides the default `'Continue with Microsoft'` text.
  const MicrosoftSignInButton({
    super.key,
    required this.onPressed,
    this.icon = const Icon(Icons.window, size: 20),
    this.label = 'Continue with Microsoft',
    this.style,
    this.width = 300,
  });

  /// The Microsoft logo widget. Defaults to a Material Icons placeholder
  /// suitable for prototyping; replace with the official brand asset for
  /// production (see class docs).
  final Widget icon;

  /// Tap handler. Pass `null` to disable the button.
  final VoidCallback? onPressed;

  /// The button text. Defaults to `'Continue with Microsoft'`.
  final String label;

  /// Optional style override for the underlying button.
  final ButtonStyle? style;

  /// The button width. Defaults to `300`.
  final double width;

  @override
  Widget build(BuildContext context) {
    return SocialSignInButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      style: style,
      width: width,
    );
  }
}

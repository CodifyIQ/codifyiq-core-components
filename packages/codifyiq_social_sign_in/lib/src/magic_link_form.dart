import 'dart:async';

import 'package:flutter/material.dart';

import 'magic_link_code_field.dart';
import 'social_sign_in_screen.dart' show SocialSignInError, buildErrorBanner;

/// Phase of the magic-link flow.
enum _MagicLinkPhase { email, submitting, linkSent }

/// An email magic-link sign-in form (the form awaits the submit callback;
/// success shows a "check your inbox" panel, a thrown exception shows an
/// inline error and keeps the email view).
///
/// Can be embedded directly, or hosted by [SocialSignInScreen] via its
/// magic-link params.
class MagicLinkForm extends StatefulWidget {
  /// Creates a [MagicLinkForm].
  ///
  /// [onSubmitEmail] sends a magic link to the entered email; the form awaits
  /// it, showing the confirmation panel on success and an inline error if it
  /// throws.
  /// [onResend] re-sends to the already-submitted email. When null, resend
  /// falls back to [onSubmitEmail].
  /// [resendCooldown] is the wait before the resend button re-enables
  /// (default 60s).
  /// [onError] receives a [SocialSignInError] for diagnostics when a send
  /// fails; the user-facing message is shown inline regardless.
  /// [onSubmitCode] verifies the cross-device fallback code; when non-null,
  /// the "check your inbox" panel surfaces a [MagicLinkCodeField] wired to
  /// it, above the resend button.
  /// [codeHelperText] is threaded to [MagicLinkCodeField.helperText]; `null`
  /// (the default) omits the helper line. Unused when [onSubmitCode] is
  /// null.
  /// [codeLength] is the expected code length, threaded to
  /// [MagicLinkCodeField.length] and to the confirmation copy (default 6).
  const MagicLinkForm({
    super.key,
    required this.onSubmitEmail,
    this.onResend,
    this.resendCooldown = const Duration(seconds: 60),
    this.onError,
    this.onLinkSentChanged,
    this.onSubmitCode,
    this.codeHelperText,
    this.codeLength = 6,
    this.minHeight,
  });

  /// Sends a magic link to [email]. Awaited by the form.
  final Future<void> Function(String email) onSubmitEmail;

  /// Re-sends to the already-submitted email. Falls back to [onSubmitEmail]
  /// when null.
  final Future<void> Function(String email)? onResend;

  /// Verifies the short code that rides along with the magic-link email
  ///
  /// When non-null, the "check your inbox" panel surfaces a
  /// [MagicLinkCodeField] below the resend button, present from the moment
  /// the panel shows. When null, no code entry is offered. Verification
  /// failures are reported via [onError], same as send/resend failures.
  final Future<void> Function(String code)? onSubmitCode;

  /// Wait before the resend button re-enables. Defaults to 60 seconds.
  final Duration resendCooldown;

  /// Receives a [SocialSignInError] for diagnostics when a send fails.
  ///
  /// Delivered after the frame in which the failure is presented, so the
  /// handler may safely call `setState` on an ancestor.
  final void Function(SocialSignInError error)? onError;

  /// Shown under the code boxes while no error is displayed, when
  /// [onSubmitCode] is non-null. Passed to [MagicLinkCodeField.helperText];
  /// `null` (the default) omits the helper line.
  final String? codeHelperText;

  /// The expected code length, when [onSubmitCode] is non-null. Passed to
  /// [MagicLinkCodeField.length] and used to derive the confirmation copy's
  /// "N-character code" phrasing. Defaults to 6.
  final int codeLength;

  /// Minimum height the form occupies across its phases.
  ///
  /// The form's phases differ in height, so content rendered below it (e.g.
  /// a host's back button) moves on phase transitions. A host that wants
  /// that content to hold still can reserve the height of its tallest
  /// expected phase here; content is top-aligned within the reservation.
  /// `null` (the default) reserves nothing.
  final double? minHeight;

  /// Called with `true` when the form enters the "check your inbox" state
  /// and `false` when it leaves it.
  ///
  /// Lets a host adapt surrounding chrome — e.g. repoint its back affordance
  /// at [MagicLinkFormState.returnToEmail] while the panel is showing.
  final ValueChanged<bool>? onLinkSentChanged;

  @override
  State<MagicLinkForm> createState() => MagicLinkFormState();

  /// Returns a copy of this form with the given fields replaced.
  ///
  /// Used by [SocialSignInScreen] to graft its own `key`, `onError`, and
  /// `onLinkSentChanged` onto the form a caller supplied via `MagicLinkButton`.
  MagicLinkForm copyWith({
    GlobalKey<MagicLinkFormState>? key,
    Future<void> Function(String email)? onSubmitEmail,
    Future<void> Function(String email)? onResend,
    Duration? resendCooldown,
    void Function(SocialSignInError error)? onError,
    ValueChanged<bool>? onLinkSentChanged,
    Future<void> Function(String code)? onSubmitCode,
    String? codeHelperText,
    int? codeLength,
    double? minHeight,
  }) {
    return MagicLinkForm(
      key: key ?? this.key,
      onSubmitEmail: onSubmitEmail ?? this.onSubmitEmail,
      onResend: onResend ?? this.onResend,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      onError: onError ?? this.onError,
      onLinkSentChanged: onLinkSentChanged ?? this.onLinkSentChanged,
      onSubmitCode: onSubmitCode ?? this.onSubmitCode,
      codeHelperText: codeHelperText ?? this.codeHelperText,
      codeLength: codeLength ?? this.codeLength,
      minHeight: minHeight ?? this.minHeight,
    );
  }
}

/// State for [MagicLinkForm], exposed so hosts can query [isLinkSent] and
/// call [returnToEmail] through a [GlobalKey].
class MagicLinkFormState extends State<MagicLinkForm> {
  static const _sendFailureMessage =
      'Could not send the link. Please try again.';
  static const _resendFailureMessage =
      'Could not resend the link. Please try again.';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  _MagicLinkPhase _phase = _MagicLinkPhase.email;
  String? _errorMessage;
  String _sentEmail = '';
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;
  bool _isResending = false;

  /// Whether the "check your inbox" panel is showing.
  bool get isLinkSent => _phase == _MagicLinkPhase.linkSent;

  /// Steps one level back through the form's internal states, returning
  /// whether a step was consumed.
  ///
  /// Hosts call this from their back handling (e.g. [PopScope]) so system
  /// back unwinds the form before leaving it. The only internal step is
  /// confirmation panel → email view.
  bool maybePop() {
    if (isLinkSent) {
      returnToEmail();
      return true;
    }
    return false;
  }

  /// Returns from the "check your inbox" panel to the email view, keeping
  /// the entered address so it can be corrected. No-op in any other state.
  void returnToEmail() {
    if (!isLinkSent) return;
    _cooldownTimer?.cancel();
    setState(() {
      _phase = _MagicLinkPhase.email;
      _cooldownRemaining = 0;
      _errorMessage = null;
      _isResending = false;
    });
    widget.onLinkSentChanged?.call(false);
  }

  /// Hands the failure to [MagicLinkForm.onError] after the current frame,
  /// matching [SocialSignInScreen.onError]'s post-frame contract so a
  /// handler may setState on an ancestor.
  void _reportError(Object error, StackTrace stack, String message) {
    final onError = widget.onError;
    if (onError == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        onError(SocialSignInError(message: message, detail: '$error\n$stack'));
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _emailFocusNode.requestFocus();
      return;
    }
    final email = _emailController.text.trim();
    setState(() {
      _phase = _MagicLinkPhase.submitting;
      _errorMessage = null;
    });
    try {
      await widget.onSubmitEmail(email);
      if (mounted) {
        setState(() {
          _phase = _MagicLinkPhase.linkSent;
          _sentEmail = email;
        });
        _startCooldown();
        widget.onLinkSentChanged?.call(true);
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _phase = _MagicLinkPhase.email;
          _errorMessage = _sendFailureMessage;
        });
        _emailFocusNode.requestFocus();
        _reportError(e, stack, _sendFailureMessage);
      }
    }
  }

  Future<void> _resend() async {
    if (_cooldownRemaining != 0 || _isResending) return;
    setState(() {
      _errorMessage = null;
      _isResending = true;
    });
    final op = widget.onResend ?? widget.onSubmitEmail;
    try {
      await op(_sentEmail);
      if (mounted) {
        setState(() => _isResending = false);
        _startCooldown();
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = _resendFailureMessage;
        });
        _reportError(e, stack, _resendFailureMessage);
      }
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    final seconds = widget.resendCooldown.inSeconds;
    if (seconds <= 0) return;
    setState(() => _cooldownRemaining = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) {
          _cooldownRemaining = 0;
          timer.cancel();
        }
      });
    });
  }

  Widget _buildEmailView(ThemeData theme) {
    return SizedBox(
      width: 300,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submit,
              child: const Text('Send magic link'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittingView(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          'Sending link…',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLinkSentView(ThemeData theme) {
    final hasCode = widget.onSubmitCode != null;
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('Check your inbox', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            hasCode
                ? 'We sent a sign-in link and a ${widget.codeLength}-character '
                      'code to $_sentEmail. Tap the link, or enter the code below.'
                : 'We sent a sign-in link to $_sentEmail. Tap it to finish '
                      'signing in.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          // When a code accompanies the link, the code+link email is one
          // artifact: the field is the primary in-app action, so it sits
          // directly under the body copy, above the resend button.
          if (hasCode) ...[
            const SizedBox(height: 16),
            MagicLinkCodeField(
              length: widget.codeLength,
              onSubmitCode: widget.onSubmitCode!,
              onError: widget.onError,
              helperText: widget.codeHelperText,
            ),
          ],
          // Resend hugs the field it relates to (or the body copy, when
          // there's no code field) rather than the unrelated back button.
          const SizedBox(height: 8),
          TextButton(
            onPressed: _cooldownRemaining == 0 && !_isResending
                ? _resend
                : null,
            // The label stays laid out (invisible) under the spinner so the
            // button keeps its size during the swap.
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: _isResending ? 0 : 1,
                  child: Text(
                    _cooldownRemaining == 0
                        ? 'Resend email'
                        : 'Resend in ${_cooldownRemaining}s',
                  ),
                ),
                if (_isResending)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: buildErrorBanner(theme, _errorMessage!),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only the active phase is built; a transition swaps the content and
    // whatever height comes with it.
    final view = switch (_phase) {
      _MagicLinkPhase.email => _buildEmailView(theme),
      _MagicLinkPhase.submitting => _buildSubmittingView(theme),
      _MagicLinkPhase.linkSent => _buildLinkSentView(theme),
    };
    final minHeight = widget.minHeight;
    if (minHeight == null) return view;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Align(alignment: Alignment.topCenter, child: view),
    );
  }
}

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'magic_link_code_field.dart';
import 'social_sign_in_screen.dart' show SocialSignInError, buildErrorBanner;

/// What the sign-in email delivers, which sets the [MagicLinkForm] copy.
enum MagicLinkDelivery {
  /// A sign-in link only; the confirmation panel asks the user to tap it.
  link,

  /// A sign-in link plus a short code for devices where the link can't be
  /// tapped. Requires [MagicLinkForm.onSubmitCode].
  linkAndCode,

  /// A short code only, for apps that can't receive links (e.g. a native
  /// mobile app without universal links / app links). No link wording is
  /// shown. Requires [MagicLinkForm.onSubmitCode].
  code,
}

/// Phase of the magic-link flow.
enum _MagicLinkPhase { email, submitting, linkSent }

/// An email magic-link sign-in form (the form awaits the submit callback;
/// success shows a "check your inbox" panel, a thrown exception shows an
/// inline error and keeps the email view).
///
/// Can be embedded directly, or hosted by [SocialSignInScreen] via its
/// magic-link params.
///
/// The "check your inbox" panel has no control of its own for going back to
/// the email field. [SocialSignInScreen] adds one; a host embedding the form
/// directly should show its own back control while
/// [MagicLinkFormState.isLinkSent] (see [onLinkSentChanged]) and wire it to
/// [MagicLinkFormState.returnToEmail], so a misspelled address can be
/// corrected rather than resent.
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
  /// [onSubmitCode] verifies the emailed code (the cross-device fallback, or
  /// the only step with [MagicLinkDelivery.code]); when non-null, the "check
  /// your inbox" panel surfaces a [MagicLinkCodeField] wired to it, above the
  /// resend button.
  /// [codeHelperText] is threaded to [MagicLinkCodeField.helperText]; `null`
  /// (the default) omits the helper line. Unused when [onSubmitCode] is
  /// null.
  /// [codeLength] is the expected code length, threaded to
  /// [MagicLinkCodeField.length] and to the confirmation copy (default 6).
  /// [delivery] is what the email contains, which sets the form's copy;
  /// `null` (the default) resolves to [MagicLinkDelivery.linkAndCode] when
  /// [onSubmitCode] is set and [MagicLinkDelivery.link] otherwise.
  ///
  /// The remaining parameters override the form's copy, e.g. to localize it.
  /// Those whose default depends on [effectiveDelivery] are nullable; `null`
  /// keeps the default wording for the mode.
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
    this.delivery,
    this.emailLabel = 'Email',
    this.emailRequiredMessage = 'Email is required',
    this.invalidEmailMessage = 'Enter a valid email',
    this.sendLabel,
    this.sendingMessage,
    this.sendFailureMessage,
    this.sentTitle = 'Check your inbox',
    this.sentMessage,
    this.noCodeHint,
    this.codeErrorMessage = 'Incorrect code. Check the email and re-enter it.',
    this.resendLabel = 'Resend email',
    this.resendCountdownLabel,
    this.resendFailureMessage,
  }) : assert(
         delivery == null ||
             (delivery == MagicLinkDelivery.link) == (onSubmitCode == null),
         'MagicLinkDelivery.link must not set onSubmitCode; '
         'linkAndCode and code require it.',
       );

  /// Sends the sign-in email to `email`. Awaited by the form.
  final Future<void> Function(String email) onSubmitEmail;

  /// Re-sends to the already-submitted email. Falls back to [onSubmitEmail]
  /// when null.
  final Future<void> Function(String email)? onResend;

  /// Verifies the short code in the sign-in email.
  ///
  /// When non-null, the "check your inbox" panel surfaces a
  /// [MagicLinkCodeField] above the resend button, present from the moment
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

  /// What the sign-in email contains, which sets the form's copy.
  ///
  /// `null` (the default) resolves to [MagicLinkDelivery.linkAndCode] when
  /// [onSubmitCode] is set and [MagicLinkDelivery.link] otherwise. See
  /// [effectiveDelivery].
  final MagicLinkDelivery? delivery;

  /// [delivery], or the mode implied by [onSubmitCode] when it's null.
  MagicLinkDelivery get effectiveDelivery =>
      delivery ??
      (onSubmitCode != null
          ? MagicLinkDelivery.linkAndCode
          : MagicLinkDelivery.link);

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

  /// Label of the email field. Defaults to `'Email'`.
  final String emailLabel;

  /// Shown under the email field when it is submitted empty. Defaults to
  /// `'Email is required'`.
  final String emailRequiredMessage;

  /// Shown under the email field when the address is malformed. Defaults to
  /// `'Enter a valid email'`.
  final String invalidEmailMessage;

  /// Label of the send button. `null` (the default) reads `'Email me a code'`
  /// for [MagicLinkDelivery.code] and `'Send magic link'` otherwise.
  final String? sendLabel;

  /// Shown under the spinner while the email is sending. `null` (the
  /// default) reads `'Sending code…'` for [MagicLinkDelivery.code] and
  /// `'Sending link…'` otherwise.
  final String? sendingMessage;

  /// Shown, and reported to [onError], when [onSubmitEmail] throws. `null`
  /// (the default) reads `'Could not send the code. Please try again.'` for
  /// [MagicLinkDelivery.code] and `'Could not send the link. …'` otherwise.
  final String? sendFailureMessage;

  /// Title of the "check your inbox" panel. Defaults to
  /// `'Check your inbox'`.
  final String sentTitle;

  /// Builds the body copy of the "check your inbox" panel from the address
  /// the email was sent to.
  ///
  /// The address is shown bold wherever it appears in the returned text.
  /// `null` (the default) uses the wording for [effectiveDelivery], e.g.
  /// `'We sent a 6-character code to <email>. Enter it below.'`.
  final String Function(String email)? sentMessage;

  /// Hint under the code field (or under the body copy when there is no code
  /// field) that a misspelled address is the usual reason nothing arrived.
  ///
  /// `null` (the default) reads `'No code after a few minutes? Check the
  /// spelling of your email and try again.'`, with "No link" or "No link or
  /// code" for [MagicLinkDelivery.link] and [MagicLinkDelivery.linkAndCode].
  ///
  /// "Try again" relies on the host offering a way back to the email field;
  /// see [MagicLinkForm].
  final String? noCodeHint;

  /// Shown under the code field when [onSubmitCode] throws. Passed to
  /// [MagicLinkCodeField.errorMessage]. Defaults to
  /// `'Incorrect code. Check the email and re-enter it.'`.
  final String codeErrorMessage;

  /// Label of the resend button once it is enabled. Defaults to
  /// `'Resend email'`.
  final String resendLabel;

  /// Builds the label of the resend button while it is cooling down, from the
  /// seconds remaining. `null` (the default) reads `'Resend in <seconds>s'`.
  final String Function(int seconds)? resendCountdownLabel;

  /// Shown, and reported to [onError], when a resend throws. `null` (the
  /// default) reads `'Could not resend the code. Please try again.'` for
  /// [MagicLinkDelivery.code] and `'Could not resend the link. …'` otherwise.
  final String? resendFailureMessage;

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
    MagicLinkDelivery? delivery,
    String? emailLabel,
    String? emailRequiredMessage,
    String? invalidEmailMessage,
    String? sendLabel,
    String? sendingMessage,
    String? sendFailureMessage,
    String? sentTitle,
    String Function(String email)? sentMessage,
    String? noCodeHint,
    String? codeErrorMessage,
    String? resendLabel,
    String Function(int seconds)? resendCountdownLabel,
    String? resendFailureMessage,
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
      delivery: delivery ?? this.delivery,
      emailLabel: emailLabel ?? this.emailLabel,
      emailRequiredMessage: emailRequiredMessage ?? this.emailRequiredMessage,
      invalidEmailMessage: invalidEmailMessage ?? this.invalidEmailMessage,
      sendLabel: sendLabel ?? this.sendLabel,
      sendingMessage: sendingMessage ?? this.sendingMessage,
      sendFailureMessage: sendFailureMessage ?? this.sendFailureMessage,
      sentTitle: sentTitle ?? this.sentTitle,
      sentMessage: sentMessage ?? this.sentMessage,
      noCodeHint: noCodeHint ?? this.noCodeHint,
      codeErrorMessage: codeErrorMessage ?? this.codeErrorMessage,
      resendLabel: resendLabel ?? this.resendLabel,
      resendCountdownLabel: resendCountdownLabel ?? this.resendCountdownLabel,
      resendFailureMessage: resendFailureMessage ?? this.resendFailureMessage,
    );
  }
}

/// State for [MagicLinkForm], exposed so hosts can query [isLinkSent] and
/// call [returnToEmail] through a [GlobalKey].
class MagicLinkFormState extends State<MagicLinkForm> {
  bool get _isCodeOnly => widget.effectiveDelivery == MagicLinkDelivery.code;

  String get _sendFailureMessage =>
      widget.sendFailureMessage ??
      (_isCodeOnly
          ? 'Could not send the code. Please try again.'
          : 'Could not send the link. Please try again.');

  String get _resendFailureMessage =>
      widget.resendFailureMessage ??
      (_isCodeOnly
          ? 'Could not resend the code. Please try again.'
          : 'Could not resend the link. Please try again.');

  String _sentMessage(String email) =>
      widget.sentMessage?.call(email) ??
      switch (widget.effectiveDelivery) {
        MagicLinkDelivery.link =>
          'We sent a sign-in link to $email. Tap it to finish signing in.',
        MagicLinkDelivery.linkAndCode =>
          'We sent a sign-in link and a ${widget.codeLength}-character code '
              'to $email. Tap the link, or enter the code below.',
        MagicLinkDelivery.code =>
          'We sent a ${widget.codeLength}-character code to $email. '
              'Enter it below.',
      };

  String get _noCodeHint {
    final missing = switch (widget.effectiveDelivery) {
      MagicLinkDelivery.link => 'No link',
      MagicLinkDelivery.linkAndCode => 'No link or code',
      MagicLinkDelivery.code => 'No code',
    };
    return widget.noCodeHint ??
        '$missing after a few minutes? Check the spelling of your email and '
            'try again.';
  }

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
              decoration: InputDecoration(
                labelText: widget.emailLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return widget.emailRequiredMessage;
                }
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                  return widget.invalidEmailMessage;
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
              child: Text(
                widget.sendLabel ??
                    (_isCodeOnly ? 'Email me a code' : 'Send magic link'),
              ),
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
          widget.sendingMessage ??
              (_isCodeOnly ? 'Sending code…' : 'Sending link…'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// The body copy, with the sent address bold wherever it appears so the
  /// person can check it at a glance.
  Widget _buildSentMessage(ThemeData theme) {
    final message = _sentMessage(_sentEmail);
    final parts = message.split(_sentEmail);
    return Text.rich(
      TextSpan(
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            if (i > 0)
              TextSpan(
                text: _sentEmail,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            TextSpan(text: parts[i]),
          ],
        ],
      ),
      style: theme.textTheme.bodyMedium,
      textAlign: TextAlign.center,
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
          Text(widget.sentTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildSentMessage(theme),
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
              errorMessage: widget.codeErrorMessage,
            ),
          ],
          // The address is the likeliest thing to be wrong when nothing
          // arrives; the hint names that cause, and the host's back
          // affordance (or resend) is the "try again".
          const SizedBox(height: 12),
          Text(
            _noCodeHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
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
                        ? widget.resendLabel
                        : widget.resendCountdownLabel?.call(
                                _cooldownRemaining,
                              ) ??
                              'Resend in ${_cooldownRemaining}s',
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

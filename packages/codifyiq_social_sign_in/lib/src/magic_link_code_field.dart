import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'social_sign_in_screen.dart' show SocialSignInError;

/// A boxed code entry field for the magic-link cross-device fallback: the
/// sign-in email carries a short code the user can type into the waiting app
/// instead of tapping the link.
///
/// Displays [length] boxes but drives them from a single hidden [TextField]
/// (one controller, so focus and paste stay simple). Submits automatically
/// once the final character is entered, or on Enter. A throw from
/// [onSubmitCode] shows an inline error and clears the entered code.
///
/// Reusable outside [MagicLinkForm] — pass it wherever a host wants standalone
/// code entry.
class MagicLinkCodeField extends StatefulWidget {
  /// Creates a [MagicLinkCodeField].
  ///
  /// [length] is the expected code length (default 6).
  /// [onSubmitCode] verifies the entered code. Awaited by the field, which
  /// shows a verifying state meanwhile; completion means the host accepted
  /// the code (the host navigates away / establishes the session); a throw
  /// shows an inline error and clears the boxes.
  /// [onError] receives a [SocialSignInError] for diagnostics when
  /// verification fails; the user-facing message is shown inline regardless.
  /// [helperText] is shown under the boxes while no error is displayed. Pass
  /// `null` (the default) to omit it — the widget doesn't assert an
  /// expiry/attempt-limit contract the host's backend may not have, so hosts
  /// choose their own copy.
  const MagicLinkCodeField({
    super.key,
    this.length = 6,
    required this.onSubmitCode,
    this.onError,
    this.helperText,
  });

  /// The expected code length. Defaults to 6.
  final int length;

  /// Verifies [code]. Awaited by the field.
  final Future<void> Function(String code) onSubmitCode;

  /// Receives a [SocialSignInError] for diagnostics when verification fails.
  ///
  /// Delivered after the frame in which the failure is presented, so the
  /// handler may safely call `setState` on an ancestor.
  final void Function(SocialSignInError error)? onError;

  /// Shown under the boxes while no error is displayed. Pass `null` to omit.
  final String? helperText;

  @override
  State<MagicLinkCodeField> createState() => _MagicLinkCodeFieldState();
}

class _MagicLinkCodeFieldState extends State<MagicLinkCodeField> {
  static const _wrongCodeMessage =
      'Incorrect code. Check the email and re-enter it.';

  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'MagicLinkCodeField.hiddenField');

  bool _verifying = false;
  String? _errorMessage;

  // The code passed to onSubmitCode while _verifying is true, so onChanged
  // can revert a stray edit back to it (see _onChanged). Null when not
  // verifying.
  String? _verifyingCode;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_pinSelectionToTip);
  }

  @override
  void dispose() {
    _controller.removeListener(_pinSelectionToTip);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Hands the failure to [MagicLinkCodeField.onError] after the current
  /// frame, matching [MagicLinkForm]'s post-frame contract so a handler may
  /// setState on an ancestor.
  void _reportError(Object error, StackTrace stack, String message) {
    final onError = widget.onError;
    if (onError == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        onError(SocialSignInError(message: message, detail: '$error\n$stack'));
      }
    });
  }

  /// Invariant: the caret never leaves the tip of [_controller]'s text — the
  /// box highlight (the next-blank box) is the only cursor the user sees.
  /// The hidden field spans all the display boxes ([Positioned.fill]), so a
  /// click's x-position lands the browser caret at an arbitrary character
  /// offset; without this, that offset and the highlighted box diverge and
  /// typing inserts mid-string. Setting `.selection` doesn't fire
  /// [TextField.onChanged], and the re-entrant controller notification sees
  /// the selection already pinned and no-ops.
  void _pinSelectionToTip() {
    final tip = TextSelection.collapsed(offset: _controller.text.length);
    if (_controller.selection != tip) {
      _controller.selection = tip;
    }
  }

  void _onChanged(String value) {
    if (_verifying) {
      // The hidden field is never disabled (see the `enabled` note in
      // build), so edits still arrive mid-verify and the controller has
      // already been mutated by the time onChanged fires; put it back so
      // the boxes stay frozen on the code that was submitted.
      _controller.text = _verifyingCode!;
      _controller.selection = TextSelection.collapsed(
        offset: _verifyingCode!.length,
      );
      return;
    }
    if (value.length == widget.length) {
      _submit(value);
    }
  }

  /// Single choke point for both submit triggers (auto-submit on the final
  /// character and the keyboard Enter/Done action): a code shorter than
  /// [MagicLinkCodeField.length] is a no-op, not an error.
  Future<void> _submit(String code) async {
    if (_verifying || code.length != widget.length) return;
    setState(() {
      _verifying = true;
      _verifyingCode = code;
      _errorMessage = null;
    });
    try {
      await widget.onSubmitCode(code);
      if (mounted) {
        setState(() {
          _verifying = false;
          _verifyingCode = null;
        });
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _verifyingCode = null;
          _errorMessage = _wrongCodeMessage;
          _controller.clear();
        });
        _reportError(e, stack, _wrongCodeMessage);
        // Safe synchronously: `enabled` never flips, so canRequestFocus
        // holds true across this rebuild.
        _focusNode.requestFocus();
      }
    }
  }

  /// Plain error-colored text, no icon — this is field-level validation
  /// feedback (like the email [TextFormField]'s validator message elsewhere
  /// in this flow), not a container/system-failure banner, so it doesn't
  /// get the icon treatment those reserve.
  Widget _buildFieldError(ThemeData theme, String message) {
    return Text(
      message,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// The single status line for the current state: the verifying spinner
  /// takes priority over an inline error, which takes priority over the
  /// helper text.
  Widget _buildStatus(ThemeData theme) {
    if (_verifying) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_errorMessage != null) {
      return _buildFieldError(theme, _errorMessage!);
    }
    // Selectable so the demo/support code in codeHelperText (e.g. "Demo: use
    // code 123-456") can be copied.
    return SelectableText(
      widget.helperText!,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildBoxes(ThemeData theme, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _buildBox(theme, i < text.length ? text[i] : '', i == text.length),
        ],
      ],
    );
  }

  Widget _buildBox(ThemeData theme, String digit, bool isCurrent) {
    final isFocused = isCurrent && _focusNode.hasFocus && !_verifying;
    return Container(
      width: 40,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: isFocused
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: isFocused ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: _verifying
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface,
      ),
      child: Text(digit, style: theme.textTheme.headlineSmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (_verifying) return;
              _focusNode.requestFocus();
            },
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([_controller, _focusNode]),
                  builder: (context, _) => _buildBoxes(theme, _controller.text),
                ),
                // Fully transparent, sized to zero on screen but still
                // focusable/editable — the boxes above are pure display.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      // Never disabled: on web, flipping `enabled` tears
                      // down the DOM input's text connection, and it never
                      // re-attaches on re-enable — onChanged goes silent
                      // for good. Verify-time inertness is done in
                      // _onChanged (reverts stray edits) and the box tap
                      // handler (skips requestFocus) instead.
                      autofocus: false,
                      keyboardType: TextInputType.text,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: widget.length,
                      // Strips dashes/whitespace from a pasted code (an
                      // extremely common separator in real codes) —
                      // beyond that, any characters are accepted verbatim.
                      // No further validation, paste transforms, or
                      // case-normalization: YAGNI until a host demonstrates
                      // a need.
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'[-\s]')),
                      ],
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      onChanged: _onChanged,
                      onSubmitted: _submit,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_verifying || _errorMessage != null || widget.helperText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildStatus(theme),
            ),
        ],
      ),
    );
  }
}

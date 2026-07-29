import 'dart:async';

import 'package:codifyiq_social_sign_in/codifyiq_social_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reservedScopesDetail =
      'Sign-in failed: {(openid, profile, "offline_access")} are reserved '
      'scopes and may not be specified in the acquire token call.';

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('SocialSignInScreen error handling', () {
    testWidgets('shows the user-safe message but never the technical detail', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SocialSignInScreen(
            logo: const FlutterLogo(),
            signInButtons: const [],
            error: const SocialSignInError(
              message: "We couldn't sign you in. Please try again.",
              detail: reservedScopesDetail,
            ),
          ),
        ),
      );

      expect(
        find.text("We couldn't sign you in. Please try again."),
        findsOneWidget,
      );
      expect(find.text(reservedScopesDetail), findsNothing);
      expect(find.textContaining('reserved scopes'), findsNothing);
    });

    testWidgets('reports the detail to onError exactly once per new error', (
      tester,
    ) async {
      final captured = <Object?>[];

      Widget build(SocialSignInError? error) => wrap(
        SocialSignInScreen(
          logo: const FlutterLogo(),
          signInButtons: const [],
          error: error,
          onError: (e) => captured.add(e.detail),
        ),
      );

      const error = SocialSignInError(detail: reservedScopesDetail);

      await tester.pumpWidget(build(error));
      await tester.pump(); // flush the post-frame callback
      expect(captured, [reservedScopesDetail]);

      // Rebuilding with the same error instance does not re-report it.
      await tester.pumpWidget(build(error));
      await tester.pump();
      expect(captured, [reservedScopesDetail]);

      // A new error instance reports again.
      await tester.pumpWidget(build(const SocialSignInError(detail: 'boom')));
      await tester.pump();
      expect(captured, [reservedScopesDetail, 'boom']);
    });

    testWidgets('renders nothing and reports nothing when error is null', (
      tester,
    ) async {
      var reported = false;
      await tester.pumpWidget(
        wrap(
          SocialSignInScreen(
            logo: const FlutterLogo(),
            signInButtons: const [],
            onError: (_) => reported = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(reported, isFalse);
    });

    testWidgets('SocialSignInError defaults to a generic safe message', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SocialSignInScreen(
            logo: const FlutterLogo(),
            signInButtons: const [],
            error: const SocialSignInError(detail: reservedScopesDetail),
          ),
        ),
      );

      expect(find.text('Sign-in failed. Please try again.'), findsOneWidget);
    });
  });

  group('SocialSignInScreen magic-link', () {
    testWidgets('reveal shows the form and always reaches "check your inbox"', (
      tester,
    ) async {
      var submits = 0;
      await tester.pumpWidget(
        wrap(
          SocialSignInScreen(
            logo: const FlutterLogo(),
            signInButtons: [
              MagicLinkButton(
                form: MagicLinkForm(
                  onSubmitEmail: (email) async => submits++,
                  resendCooldown: Duration.zero,
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Continue with email'), findsOneWidget);
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();

      // Client-side validation is the only guard against garbage sends —
      // the always-success UX would still show "check your inbox".
      await tester.enterText(find.byType(TextFormField), 'notanemail');
      await tester.tap(find.text('Send magic link'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(submits, 0);

      // A valid address submits via the keyboard action (Enter).
      await tester.enterText(find.byType(TextFormField), 'a@b.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Check your inbox'), findsOneWidget);
      expect(submits, 1);

      // No onSubmitCode was provided, so the code-entry fallback is absent —
      // config-driven, not conditionally shown.
      expect(find.byType(MagicLinkCodeField), findsNothing);
      expect(find.text('Resend email'), findsOneWidget);

      // Two-stage back: the confirmation panel's escape re-enters the email
      // view with the address kept for correction.
      await tester.tap(find.text('Re-enter address'));
      await tester.pumpAndSettle();
      expect(find.text('Check your inbox'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller
            ?.text,
        'a@b.com',
      );
      expect(find.text('Back to sign-in options'), findsOneWidget);

      // System back steps the reveal back to the button column instead of
      // popping the route.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Continue with email'), findsOneWidget);
    });

    testWidgets('cooldown disables then re-enables resend', (tester) async {
      var resendCompleter = Completer<void>();
      final codesSubmitted = <String>[];
      await tester.pumpWidget(
        wrap(
          SocialSignInScreen(
            logo: const FlutterLogo(),
            signInButtons: [
              MagicLinkButton(
                form: MagicLinkForm(
                  onSubmitEmail: (email) async {},
                  onResend: (email) => resendCompleter.future,
                  resendCooldown: const Duration(seconds: 2),
                  onSubmitCode: (code) async => codesSubmitted.add(code),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'a@b.com');
      await tester.tap(find.text('Send magic link'));
      await tester.pump();
      await tester.pump();

      final resendButtonFinder = find.descendant(
        of: find.byType(MagicLinkForm),
        matching: find.byType(TextButton),
      );
      TextButton resendButton() =>
          tester.widget<TextButton>(resendButtonFinder);

      expect(find.text('Resend in 2s'), findsOneWidget);
      expect(resendButton().onPressed, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend in 1s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      // onSubmitCode is provided in this test, so the code+link email is one
      // artifact and the resend button reads "Resend email".
      expect(find.text('Resend email'), findsOneWidget);
      expect(resendButton().onPressed, isNotNull);

      // A resend failure shows the banner.
      await tester.tap(find.text('Resend email'));
      await tester.pump();
      resendCompleter.completeError(Exception('resend boom'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Could not resend the link. Please try again.'),
        findsOneWidget,
      );
      resendCompleter = Completer<void>();
      expect(find.text('Resend email'), findsOneWidget);

      // In flight: button disabled, inline spinner overlaid on the label —
      // which stays laid out at zero opacity so the button keeps its size —
      // and no countdown until the callback resolves.
      await tester.tap(find.text('Resend email'));
      await tester.pump();
      expect(resendButton().onPressed, isNull);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: find.text('Resend email'),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0,
      );
      expect(find.textContaining('Resend in'), findsNothing);
      expect(
        find.descendant(
          of: resendButtonFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      resendCompleter.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Resend in 2s'), findsOneWidget);
      expect(resendButton().onPressed, isNull);

      // Drain the restarted cooldown so no timers are pending at test end.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend email'), findsOneWidget);

      // onSubmitCode was provided, so the code-entry fallback is present
      // above the resend button (the code+link email is one artifact), and
      // a correct code reaches the host.
      expect(
        find.textContaining('We sent a sign-in link and a 6-character code to'),
        findsOneWidget,
      );
      // No codeHelperText was provided, so no helper line renders (null
      // means omit it, not a built-in default).
      expect(
        find.descendant(
          of: find.byType(MagicLinkCodeField),
          matching: find.byType(SelectableText),
        ),
        findsNothing,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(MagicLinkCodeField),
          matching: find.byType(TextField),
        ),
        '123456',
      );
      await tester.pumpAndSettle();
      expect(codesSubmitted, ['123456']);
    });
  });

  group('MagicLinkCodeField', () {
    Finder hiddenField() => find.byType(TextField);

    // TextField requires a Material ancestor; MaterialApp alone (without a
    // Scaffold) doesn't provide one.
    Widget wrapWithMaterial(Widget child) =>
        wrap(Material(child: Center(child: child)));

    testWidgets('pasting a full code strips separators and auto-submits '
        'exactly once', (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        wrapWithMaterial(
          MagicLinkCodeField(onSubmitCode: (code) async => submitted.add(code)),
        ),
      );

      // Simulates a paste of a code with a separator; the strip-separators
      // formatter reduces it to the 6 characters and auto-submits on the
      // final one.
      await tester.enterText(hiddenField(), '123-456');
      await tester.pumpAndSettle();

      expect(submitted, ['123456']);
      // The boxes render each digit once auto-submit completes.
      for (final digit in '123456'.split('')) {
        expect(find.text(digit), findsOneWidget);
      }

      // No digit-only assumption: the field is a generic short-code entry,
      // so letters pass straight through untouched (only dashes/whitespace
      // are stripped).
      submitted.clear();
      await tester.enterText(hiddenField(), 'AB12CD');
      await tester.pumpAndSettle();
      expect(submitted, ['AB12CD']);
    });

    testWidgets('wrong code shows an inline error and clears the boxes', (
      tester,
    ) async {
      var attempts = 0;
      final completer = Completer<void>();
      await tester.pumpWidget(
        wrapWithMaterial(
          MagicLinkCodeField(
            onSubmitCode: (code) {
              attempts++;
              return completer.future;
            },
          ),
        ),
      );

      // A partial code fired via the keyboard Enter/Done action (not just
      // auto-submit's length check) must be a no-op: no callback, no error.
      await tester.enterText(hiddenField(), '111');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(attempts, 0);
      expect(
        find.text('Incorrect code. Check the email and re-enter it.'),
        findsNothing,
      );

      // A click can land the browser caret mid-string (the hidden field
      // spans every box); it must snap back to the tip.
      final hiddenController = tester.widget<TextField>(hiddenField())
          .controller!;
      hiddenController.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      expect(
        hiddenController.selection,
        TextSelection.collapsed(offset: hiddenController.text.length),
      );

      await tester.enterText(hiddenField(), '111111');
      await tester.pump();

      expect(attempts, 1);
      // While the submission is in flight, a spinner shows below the boxes.
      expect(
        find.descendant(
          of: find.byType(MagicLinkCodeField),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      // The field stays enabled mid-verify, so keystrokes still arrive —
      // they must be reverted, leaving the boxes on the submitted code.
      await tester.enterText(hiddenField(), '999999');
      await tester.pump();
      expect(
        tester.widget<TextField>(hiddenField()).controller?.text,
        '111111',
      );
      expect(attempts, 1);

      completer.completeError(Exception('bad code'));
      // A single frame — not pumpAndSettle — so the assertion below pins the
      // *first* moment the field is refocused after the error, matching a
      // real focus traversal instead of letting settle's repeated pumping
      // paper over a request that never actually landed on this frame.
      await tester.pump();

      expect(
        find.text('Incorrect code. Check the email and re-enter it.'),
        findsOneWidget,
      );
      expect(find.text('1'), findsNothing);
      expect(tester.widget<TextField>(hiddenField()).controller?.text, isEmpty);
      // The hidden field never sets `enabled` at all (disabling it tears
      // down its web DOM input connection for good, see the widget doc),
      // so TextField.enabled reads null — not false — throughout. This is
      // just confirming that invariant holds post-error, and that the
      // refocus (issued synchronously in the catch handler, no post-frame
      // deferral needed now that `enabled` never flips) landed on this same
      // frame.
      final hiddenTextField = tester.widget<TextField>(hiddenField());
      expect(hiddenTextField.enabled, isNot(false));
      expect(hiddenTextField.focusNode?.hasFocus, isTrue);

      await tester.pumpAndSettle();
    });
  });
}

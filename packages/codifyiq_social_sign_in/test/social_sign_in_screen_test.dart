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
}

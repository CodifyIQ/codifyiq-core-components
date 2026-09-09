import 'package:codifyiq_terms_and_conditions/codifyiq_terms_and_conditions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Terms long enough to overflow any test viewport, so the scroll gate stays
/// closed until the test explicitly scrolls to the end.
final String _longTerms = 'Lorem ipsum dolor sit amet.\n\n' * 80;

/// Terms short enough to fit the viewport, which opens the scroll gate on the
/// first frame.
const String _shortTerms = 'Lorem ipsum.';

Widget _harness({
  String? termsContent,
  VoidCallback? onAccepted,
  bool isProcessing = false,
  String? readPromptLabel,
  String? acceptLabel,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TermsAndConditionsWidget(
        termsContent: termsContent ?? _longTerms,
        onAccepted: onAccepted,
        isProcessing: isProcessing,
        readPromptLabel: readPromptLabel ?? 'Read to accept',
        acceptLabel: acceptLabel ?? 'Accept',
      ),
    ),
  );
}

FilledButton _button(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  group('acceptance button', () {
    testWidgets('is disabled and prompts to read before scrolling to the end', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(onAccepted: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Read to accept'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('is enabled and invokes onAccepted once scrolled to the end', (
      tester,
    ) async {
      var accepted = 0;
      await tester.pumpWidget(_harness(onAccepted: () => accepted++));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -20000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accept'), findsOneWidget);
      expect(_button(tester).onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      expect(accepted, 1);
    });

    testWidgets('opens the gate immediately when the terms fit the viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(termsContent: _shortTerms, onAccepted: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accept'), findsOneWidget);
      expect(_button(tester).onPressed, isNotNull);
    });

    testWidgets('is disabled when onAccepted is null, even once scrolled', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(termsContent: _shortTerms));
      await tester.pumpAndSettle();

      expect(find.text('Accept'), findsOneWidget);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('shows a progress indicator and is disabled while processing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          termsContent: _shortTerms,
          onAccepted: () {},
          isProcessing: true,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('re-closes when the terms are replaced', (tester) async {
      // Short terms open the gate immediately; the replacement has not been
      // read, so the gate must close again rather than carry the acceptance
      // of one document over to another.
      await tester.pumpWidget(
        _harness(termsContent: _shortTerms, onAccepted: () {}),
      );
      await tester.pumpAndSettle();
      expect(_button(tester).onPressed, isNotNull);

      await tester.pumpWidget(
        _harness(termsContent: _longTerms, onAccepted: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Read to accept'), findsOneWidget);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('processing indicator uses the button foreground colour', (
      tester,
    ) async {
      final theme = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF18D777)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: TermsAndConditionsWidget(
              termsContent: _shortTerms,
              onAccepted: () {},
              isProcessing: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final color = tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .color!;

      // The disabled button paints its label at 38% opacity; the indicator
      // stands in for that label and must match it, not the page's text, which
      // is the same hue but fully opaque.
      final onSurface = theme.colorScheme.onSurface;
      expect(color.a, closeTo(0.38, 0.01));
      expect(color.withValues(alpha: 1), onSurface);
    });

    testWidgets('does not unlock when the viewport has no height', (
      tester,
    ) async {
      // A viewport with no height reports a zero scroll extent, the same thing
      // terms short enough to fit report. Nothing has been shown to the user,
      // so the gate must stay shut.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 0,
              child: TermsAndConditionsWidget(
                termsContent: '',
                onAccepted: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('uses the supplied labels', (tester) async {
      await tester.pumpWidget(
        _harness(
          onAccepted: () {},
          readPromptLabel: 'Lire pour accepter',
          acceptLabel: 'Accepter',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lire pour accepter'), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -20000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accepter'), findsOneWidget);
    });
  });

  group('label layout', () {
    /// Renders the widget at the given viewport width and text scale and
    /// reports the height of the button's paragraph.
    ///
    /// [terms] selects the gate state: short terms open it and show the accept
    /// label, long terms leave it closed and show the read prompt.
    Future<double> labelHeight(
      WidgetTester tester, {
      required String terms,
      required String label,
      required double width,
      required double textScale,
    }) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: _harness(termsContent: terms, onAccepted: () {}),
        ),
      );
      await tester.pumpAndSettle();

      return tester.renderObject<RenderParagraph>(find.text(label)).size.height;
    }

    /// A label that wraps is taller when the viewport constrains it than when
    /// it has all the room it wants.
    Future<void> expectOneLine(
      WidgetTester tester, {
      required String terms,
      required String label,
      required double width,
    }) async {
      final constrained = await labelHeight(
        tester,
        terms: terms,
        label: label,
        width: width,
        textScale: 1.3,
      );
      final unconstrained = await labelHeight(
        tester,
        terms: terms,
        label: label,
        width: 2000,
        textScale: 1.3,
      );

      expect(constrained, unconstrained);
    }

    testWidgets('default accept label stays on one line at 320dp and 1.3x', (
      tester,
    ) async {
      await expectOneLine(
        tester,
        terms: _shortTerms,
        label: 'Accept',
        width: 320,
      );
    });

    testWidgets('default read prompt stays on one line at 360dp and 1.3x', (
      tester,
    ) async {
      await expectOneLine(
        tester,
        terms: _longTerms,
        label: 'Read to accept',
        width: 360,
      );
    });
  });

  group('theme changes', () {
    ThemeData themeFor(Brightness b) => ThemeData(
      brightness: b,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF18D777),
        brightness: b,
      ),
    );

    /// The colour the rendered "Section Heading" span resolves to.
    Color? headingColor(WidgetTester tester) {
      for (final e in find.byType(RichText).evaluate()) {
        Color? found;
        void walk(InlineSpan s) {
          if (s is TextSpan) {
            if ((s.text ?? '').contains('Section Heading')) {
              found = s.style?.color;
            }
            for (final c in s.children ?? const <InlineSpan>[]) {
              walk(c);
            }
          }
        }

        walk((e.renderObject! as RenderParagraph).text);
        if (found != null) return found;
      }
      return null;
    }

    Widget app(Brightness b) => MaterialApp(
      theme: themeFor(b),
      home: Scaffold(
        body: TermsAndConditionsWidget(
          termsContent: '## Section Heading\n\n$_shortTerms',
          onAccepted: () {},
        ),
      ),
    );

    testWidgets('markdown headings follow a live light/dark switch', (
      tester,
    ) async {
      await tester.pumpWidget(app(Brightness.light));
      await tester.pumpAndSettle();
      expect(
        headingColor(tester),
        themeFor(Brightness.light).colorScheme.onSurface,
      );

      // Switching brightness with the screen already open must repaint the
      // headings; leaving them at the old colour renders them near-invisible.
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pumpAndSettle();
      expect(
        headingColor(tester),
        themeFor(Brightness.dark).colorScheme.onSurface,
      );
    });
  });
}

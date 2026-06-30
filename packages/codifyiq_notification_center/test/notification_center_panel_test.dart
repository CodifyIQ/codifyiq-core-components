import 'package:codifyiq_notification_center/codifyiq_notification_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Pumps the panel inside a minimal Material host. Uses pump() rather than
  // pumpAndSettle() throughout because a running row may host an indeterminate
  // CircularProgressIndicator, whose animation never settles.
  Future<void> pumpPanel(
    WidgetTester tester,
    NotificationCenterController controller, {
    Widget? emptyPlaceholder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationCenterPanel(
            controller: controller,
            emptyPlaceholder: emptyPlaceholder,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('NotificationCenterPanel', () {
    testWidgets('empty controller shows the default placeholder', (
      tester,
    ) async {
      await pumpPanel(tester, NotificationCenterController());

      expect(find.text('No notifications'), findsOneWidget);
    });

    testWidgets('emptyPlaceholder override replaces the default', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        NotificationCenterController(),
        emptyPlaceholder: const Text('Nothing here yet'),
      );

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('No notifications'), findsNothing);
    });

    testWidgets('renders title, description, and section header', (
      tester,
    ) async {
      final controller = NotificationCenterController()
        ..start(id: 'a', title: 'Uploading report.pdf', description: 'Starting');

      await pumpPanel(tester, controller);

      expect(find.text('Uploading report.pdf'), findsOneWidget);
      expect(find.text('Starting'), findsOneWidget);
      // Section labels are upper-cased in the panel.
      expect(find.text('IN PROGRESS'), findsOneWidget);
    });

    group('single progress indicator per running row (#53)', () {
      testWidgets(
        'indeterminate task shows only the spinner — never the bar',
        (tester) async {
          // progress == null (unknown duration) is signalled solely by the
          // leading spinner. The linear bar carries a value it doesn't have,
          // so it must not appear.
          final controller = NotificationCenterController()
            ..start(id: 'a', title: 'Working');

          await pumpPanel(tester, controller);

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(find.byIcon(Icons.sync), findsNothing);
        },
      );

      testWidgets(
        'determinate task shows only the bar — no leading glyph, never the spinner',
        (tester) async {
          // A real percentage lives in the legible linear bar; the leading slot
          // is dropped entirely so nothing competes with the bar.
          final controller = NotificationCenterController()
            ..start(id: 'a', title: 'Working', progress: 0.5);

          await pumpPanel(tester, controller);

          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          expect(find.byIcon(Icons.sync), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          // The bar must carry the value — a determinate task rendered with an
          // indeterminate bar (value == null) would defeat the whole point.
          final bar = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(bar.value, 0.5);
        },
      );

      testWidgets(
        'live update from indeterminate to determinate swaps the indicator',
        (tester) async {
          final controller = NotificationCenterController()
            ..start(id: 'a', title: 'Working');
          await pumpPanel(tester, controller);

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsNothing);

          controller.updateProgress('a', progress: 0.5);
          await tester.pump();

          // The row rebuilds via itemListenable — spinner gives way to bar.
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          expect(find.byIcon(Icons.sync), findsNothing);
          final bar = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(bar.value, 0.5);
        },
      );

      testWidgets(
        'clearProgress reverts a determinate row to the spinner',
        (tester) async {
          // The mirror of the swap above, and the documented "verifying…"
          // path: a determinate bar returns to an indeterminate spinner.
          final controller = NotificationCenterController()
            ..start(id: 'a', title: 'Working', progress: 0.5);
          await pumpPanel(tester, controller);

          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          expect(find.byIcon(Icons.sync), findsNothing);

          controller.updateProgress('a', clearProgress: true);
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(find.byIcon(Icons.sync), findsNothing);
        },
      );

      testWidgets(
        'mixed running rows each keep exactly one indicator',
        (tester) async {
          final controller = NotificationCenterController()
            ..start(id: 'a', title: 'Indeterminate')
            ..start(id: 'b', title: 'Determinate', progress: 0.3);

          await pumpPanel(tester, controller);

          // One spinner (the null row), one bar (the 0.3 row) — not two of each.
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          expect(find.byIcon(Icons.sync), findsNothing);
        },
      );
    });

    testWidgets('succeeded item shows the success glyph and no progress UI', (
      tester,
    ) async {
      final controller = NotificationCenterController()
        ..start(id: 'a', title: 'Working')
        ..complete('a', description: 'Done');

      await pumpPanel(tester, controller);

      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // complete() sets progress to 1.0, but a finished row shows no bar.
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('failed item shows the error glyph and no progress UI', (
      tester,
    ) async {
      final controller = NotificationCenterController()
        ..start(id: 'a', title: 'Working', progress: 0.4)
        ..fail('a', description: 'Boom');

      await pumpPanel(tester, controller);

      expect(find.text('FAILED'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('completed row exposes a working dismiss button', (
      tester,
    ) async {
      final controller = NotificationCenterController()
        ..start(id: 'a', title: 'Working')
        ..complete('a');

      await pumpPanel(tester, controller);
      expect(find.text('Working'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();

      expect(controller.itemById('a'), isNull);
      expect(find.text('Working'), findsNothing);
    });

    testWidgets('running row has no dismiss affordance', (tester) async {
      final controller = NotificationCenterController()
        ..start(id: 'a', title: 'Working');

      await pumpPanel(tester, controller);

      expect(find.byTooltip('Dismiss'), findsNothing);
    });

    testWidgets('trailing action fires its callback', (tester) async {
      var tapped = 0;
      final controller = NotificationCenterController()
        ..start(id: 'a', title: 'Working')
        ..complete(
          'a',
          action: NotificationItemAction(
            label: 'Open',
            onPressed: () => tapped++,
          ),
        );

      await pumpPanel(tester, controller);

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('Clear completed removes finished items but keeps running', (
      tester,
    ) async {
      final controller = NotificationCenterController()
        ..start(id: 'a', title: 'Still going')
        ..start(id: 'b', title: 'Finished')
        ..complete('b');

      await pumpPanel(tester, controller);

      await tester.tap(find.text('Clear completed'));
      await tester.pump();

      expect(controller.itemById('a'), isNotNull);
      expect(controller.itemById('b'), isNull);
      expect(find.text('Finished'), findsNothing);
      expect(find.text('Still going'), findsOneWidget);
    });
  });
}

import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = <Group>[
  Group(id: 'admin', name: 'Admin'),
  Group(id: 'edit', name: 'Editors'),
];

/// Pumps a host whose button opens [open] and records what it resolves with.
Future<List<Object?>> _host(
  WidgetTester tester,
  Future<Object?> Function(BuildContext context) open,
) async {
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async => results.add(await open(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

/// Taps the modal barrier — "clicking off" the dialog or sheet.
Future<void> _tapBarrier(WidgetTester tester) async {
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
}

void main() {
  group('GroupEditorDialog discard guard', () {
    testWidgets('clicking off an untouched dialog still dismisses it', (
      tester,
    ) async {
      final results = await _host(tester, (c) => GroupEditorDialog.show(c));

      await _tapBarrier(tester);

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New group'), findsNothing);
      expect(results, <Object?>[null]);
    });

    testWidgets('clicking off after typing asks before discarding', (
      tester,
    ) async {
      final results = await _host(tester, (c) => GroupEditorDialog.show(c));
      await tester.enterText(find.byType(TextFormField).first, 'Auditors');
      await tester.pump();

      await _tapBarrier(tester);

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(results, isEmpty);

      // Keeping the edits leaves the editor open with the text intact.
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('New group'), findsOneWidget);
      expect(find.text('Auditors'), findsOneWidget);
      expect(results, isEmpty);

      // Confirming discards them and closes the editor with no group.
      await _tapBarrier(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('New group'), findsNothing);
      expect(results, <Object?>[null]);
    });

    testWidgets('Cancel routes through the same prompt', (tester) async {
      final results = await _host(tester, (c) => GroupEditorDialog.show(c));
      await tester.enterText(find.byType(TextFormField).first, 'Auditors');
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('editing back to the original values clears the guard', (
      tester,
    ) async {
      final results = await _host(
        tester,
        (c) => GroupEditorDialog.show(
          c,
          initial: const Group(id: 'admin', name: 'Admin'),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Admins');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, 'Admin');
      await tester.pump();

      await _tapBarrier(tester);

      expect(find.text('Discard changes?'), findsNothing);
      expect(results, <Object?>[null]);
    });

    testWidgets('Save is never intercepted', (tester) async {
      final results = await _host(tester, (c) => GroupEditorDialog.show(c));
      await tester.enterText(find.byType(TextFormField).first, 'Auditors');
      await tester.pump();

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(results.single, isA<Group>());
      expect((results.single! as Group).name, 'Auditors');
    });
  });

  group('GroupPicker discard guard', () {
    testWidgets('clicking off with no selection change dismisses', (
      tester,
    ) async {
      final results = await _host(
        tester,
        (c) => GroupPicker.show(c, groups: _catalog),
      );

      await _tapBarrier(tester);

      expect(find.text('Discard changes?'), findsNothing);
      expect(results, <Object?>[null]);
    });

    testWidgets('clicking off after toggling a row asks first', (tester) async {
      final results = await _host(
        tester,
        (c) => GroupPicker.show(c, groups: _catalog),
      );
      await tester.tap(find.text('Editors'));
      await tester.pumpAndSettle();

      await _tapBarrier(tester);

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(results, isEmpty);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(results, <Object?>[null]);
    });

    testWidgets('the compact bottom-sheet surface is guarded too', (
      tester,
    ) async {
      // Below the 600dp breakpoint the picker is a modal bottom sheet, a
      // separate dismissal path from the dialog.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final results = await _host(
        tester,
        (c) => GroupPicker.show(c, groups: _catalog),
      );
      await tester.tap(find.text('Editors'));
      await tester.pumpAndSettle();

      await _tapBarrier(tester);

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('confirming the selection is never intercepted', (
      tester,
    ) async {
      final results = await _host(
        tester,
        (c) => GroupPicker.show(c, groups: _catalog),
      );
      await tester.tap(find.text('Editors'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(results, <Object?>[
        <String>{'edit'},
      ]);
    });
  });
}

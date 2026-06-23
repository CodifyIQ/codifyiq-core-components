import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = <Group>[
  Group(id: 'admin', name: 'Admin'),
  Group(id: 'edit', name: 'Editors'),
];

void main() {
  group('GroupAssignmentField locked groups', () {
    testWidgets('locked group renders as a chip even when not selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupAssignmentField(
              groups: _catalog,
              selected: const <String>{},
              lockedIds: const <String>{'admin'},
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Shown despite being absent from `selected`...
      expect(find.text('Admin'), findsOneWidget);
      // ...as a non-removable Chip (not a removable InputChip) bearing a lock
      // glyph in place of the delete affordance.
      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(Chip), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byTooltip('Remove Admin'), findsNothing);
      expect(find.byTooltip("Required — can't be removed"), findsOneWidget);
    });

    testWidgets('removing an unlocked chip preserves the locked id', (
      tester,
    ) async {
      Set<String>? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupAssignmentField(
              groups: _catalog,
              selected: const <String>{'edit'},
              lockedIds: const <String>{'admin'},
              onChanged: (ids) => changed = ids,
            ),
          ),
        ),
      );

      // Admin (locked) + Editors (removable) both visible.
      expect(find.byType(Chip), findsOneWidget);
      expect(find.byType(InputChip), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Editors'));
      await tester.pump();

      // The unlocked id is dropped, but the locked id is folded back in even
      // though the caller never put it in `selected` — a locked group can
      // never be removed through the chip path.
      expect(changed, <String>{'admin'});
    });
  });

  group('GroupPicker locked groups', () {
    Future<void> openPicker(
      WidgetTester tester, {
      Set<String> lockedIds = const <String>{},
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => GroupPicker.show(
                  context,
                  groups: _catalog,
                  lockedIds: lockedIds,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('locked row is checked and disabled', (tester) async {
      await openPicker(tester, lockedIds: const <String>{'admin'});

      final tile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Admin'),
      );
      expect(tile.value, isTrue);
      expect(tile.enabled, isFalse);
      expect(tile.onChanged, isNull);
      // Lock glyph beside the locked row's name; the unlocked row has none.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byTooltip("Required — can't be removed"), findsOneWidget);
    });

    testWidgets('Done count reflects the locked union', (tester) async {
      await openPicker(tester, lockedIds: const <String>{'admin'});

      // Locked id counts even though the user selected nothing.
      expect(find.text('Done (1)'), findsOneWidget);
    });

    testWidgets('locked id is always returned, even with no interaction', (
      tester,
    ) async {
      late Set<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await GroupPicker.show(
                    context,
                    groups: _catalog,
                    lockedIds: const <String>{'admin'},
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done (1)'));
      await tester.pumpAndSettle();

      expect(result, <String>{'admin'});
    });

    testWidgets('user selections are merged with locked ids on confirm', (
      tester,
    ) async {
      late Set<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await GroupPicker.show(
                    context,
                    groups: _catalog,
                    lockedIds: const <String>{'admin'},
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Editors'));
      await tester.pumpAndSettle();
      expect(find.text('Done (2)'), findsOneWidget);

      await tester.tap(find.text('Done (2)'));
      await tester.pumpAndSettle();

      expect(result, <String>{'admin', 'edit'});
    });
  });

  group('GroupListView locked groups', () {
    Future<void> pumpList(WidgetTester tester) async {
      final controller = GroupManagerController(groups: _catalog);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupListView(
              controller: controller,
              lockedIds: const <String>{'admin'},
            ),
          ),
        ),
      );
    }

    testWidgets('locked group row offers Edit but no Delete', (tester) async {
      await pumpList(tester);

      // _catalog order is [admin, edit]; the first row menu is the locked one.
      await tester.tap(find.byTooltip('Group actions').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('only the locked row shows the lock cue', (tester) async {
      await pumpList(tester);

      // One lock badge, on the locked group's row, explaining the missing
      // Delete action. The unlocked row has none.
      expect(find.byTooltip("Locked — can't be deleted"), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('unlocked group row still offers Delete', (tester) async {
      await pumpList(tester);

      await tester.tap(find.byTooltip('Group actions').at(1));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });
}

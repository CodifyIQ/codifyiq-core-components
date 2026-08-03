import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupManagerController catalog', () {
    test('seeds groups in insertion order', () {
      final controller = GroupManagerController(
        groups: const [
          Group(id: 'a', name: 'Alpha'),
          Group(id: 'b', name: 'Beta'),
        ],
      );
      expect(controller.groups.map((g) => g.id), ['a', 'b']);
      expect(controller.length, 2);
      expect(controller.groupById('b')?.name, 'Beta');
    });

    test('addGroup appends and notifies', () {
      final controller = GroupManagerController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.addGroup(const Group(id: 'a', name: 'Alpha'));

      expect(controller.groups.single.id, 'a');
      expect(notifications, 1);
    });

    test('addGroup rejects duplicate ids', () {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      expect(
        () => controller.addGroup(const Group(id: 'a', name: 'Again')),
        throwsArgumentError,
      );
    });

    test('updateGroup replaces in place and requires existence', () {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      controller.updateGroup(const Group(id: 'a', name: 'Alpha Prime'));
      expect(controller.groupById('a')?.name, 'Alpha Prime');

      expect(
        () => controller.updateGroup(const Group(id: 'z', name: 'Nope')),
        throwsArgumentError,
      );
    });

    test('removeGroup cascades to assignments', () {
      final controller = GroupManagerController(
        groups: const [
          Group(id: 'a', name: 'Alpha'),
          Group(id: 'b', name: 'Beta'),
        ],
      );
      controller.assign('user1', 'a');
      controller.assign('user1', 'b');

      controller.removeGroup('a');

      expect(controller.groupById('a'), isNull);
      expect(controller.groupsFor('user1'), {'b'});
    });

    test('removeGroup is a no-op for unknown id', () {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.removeGroup('missing');
      expect(notifications, 0);
    });
  });

  group('GroupManagerController assignments', () {
    test('assign / isAssigned / unassign', () {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      expect(controller.isAssigned('u', 'a'), isFalse);

      controller.assign('u', 'a');
      expect(controller.isAssigned('u', 'a'), isTrue);
      expect(controller.groupsFor('u'), {'a'});

      controller.unassign('u', 'a');
      expect(controller.isAssigned('u', 'a'), isFalse);
      expect(controller.groupsFor('u'), isEmpty);
    });

    test('assign throws on unknown groups', () {
      final controller = GroupManagerController();
      var notifications = 0;
      controller.addListener(() => notifications++);
      expect(() => controller.assign('u', 'ghost'), throwsArgumentError);
      expect(controller.groupsFor('u'), isEmpty);
      expect(notifications, 0);
    });

    test('duplicate assign does not notify twice', () {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.assign('u', 'a');
      controller.assign('u', 'a');
      expect(notifications, 1);
    });

    test('setAssignments filters unknown ids and clears when empty', () {
      final controller = GroupManagerController(
        groups: const [
          Group(id: 'a', name: 'Alpha'),
          Group(id: 'b', name: 'Beta'),
        ],
      );
      controller.setAssignments('u', {'a', 'b', 'ghost'});
      expect(controller.groupsFor('u'), {'a', 'b'});

      controller.setAssignments('u', <String>{});
      expect(controller.groupsFor('u'), isEmpty);
    });

    test('setAssignments is a no-op when unchanged', () {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      controller.assign('u', 'a');
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.setAssignments('u', {'a'});
      expect(notifications, 0);
    });

    test('resolvedGroupsFor returns groups in catalog order', () {
      final controller = GroupManagerController(
        groups: const [
          Group(id: 'a', name: 'Alpha'),
          Group(id: 'b', name: 'Beta'),
          Group(id: 'c', name: 'Gamma'),
        ],
      );
      // Assigned out of catalog order…
      controller.setAssignments('u', {'c', 'a'});
      // …but resolved back in catalog order.
      expect(controller.resolvedGroupsFor('u').map((g) => g.id), ['a', 'c']);
    });

    test('groupsFor returns an unmodifiable snapshot', () {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      controller.assign('u', 'a');
      expect(() => controller.groupsFor('u').add('b'), throwsUnsupportedError);
    });

    test('assignMany adds groups to every principal, additively', () {
      final controller = GroupManagerController(
        groups: const [
          Group(id: 'a', name: 'Alpha'),
          Group(id: 'b', name: 'Beta'),
          Group(id: 'c', name: 'Gamma'),
        ],
      );
      controller.assign('u1', 'c');

      controller.assignMany(['u1', 'u2'], ['a', 'b', 'ghost']);

      expect(controller.groupsFor('u1'), {'a', 'b', 'c'});
      expect(controller.groupsFor('u2'), {'a', 'b'});
    });

    test('assignMany notifies once for the whole batch, none if unchanged', () {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.assignMany(['u1', 'u2'], ['a']);
      expect(notifications, 1);

      controller.assignMany(['u1', 'u2'], ['a']);
      expect(notifications, 1);

      controller.assignMany(['u1', 'u2'], ['ghost']);
      expect(notifications, 1);
    });

    test('unassignMany removes groups from every principal', () {
      final controller = GroupManagerController(
        groups: const [
          Group(id: 'a', name: 'Alpha'),
          Group(id: 'b', name: 'Beta'),
        ],
      );
      controller.assignMany(['u1', 'u2'], ['a', 'b']);

      controller.unassignMany(['u1', 'u2'], ['a']);

      expect(controller.groupsFor('u1'), {'b'});
      expect(controller.groupsFor('u2'), {'b'});
    });

    test('unassignMany drops a principal left with no memberships', () {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      controller.assign('u1', 'a');

      controller.unassignMany(['u1'], ['a']);

      expect(controller.groupsFor('u1'), isEmpty);
    });

    test(
      'unassignMany notifies once for the whole batch, none if unchanged',
      () {
        final controller = GroupManagerController(
          groups: const [Group(id: 'a', name: 'Alpha')],
        );
        controller.assign('u1', 'a');
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.unassignMany(['u1', 'u2'], ['a']);
        expect(notifications, 1);

        controller.unassignMany(['u1'], ['a']);
        expect(notifications, 1);
      },
    );
  });

  group('Group model', () {
    test('copyWith replaces and clears fields', () {
      const group = Group(id: 'a', name: 'Alpha', description: 'desc');
      expect(group.copyWith(name: 'Beta').name, 'Beta');
      expect(group.copyWith(name: 'Beta').description, 'desc');
      expect(group.copyWith(clearDescription: true).description, isNull);
    });

    test('equality is by value', () {
      const a = Group(id: 'a', name: 'Alpha');
      const b = Group(id: 'a', name: 'Alpha');
      const c = Group(id: 'a', name: 'Different');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith updates and clears the color role', () {
      const group = Group(id: 'a', name: 'Alpha', color: GroupColor.primary);
      expect(
        group.copyWith(color: GroupColor.tertiary).color,
        GroupColor.tertiary,
      );
      expect(group.copyWith(clearColor: true).color, isNull);
    });
  });

  group('GroupColor', () {
    test('auto is deterministic and never neutral', () {
      // Stable for a given id across calls…
      expect(GroupColor.auto('admins'), GroupColor.auto('admins'));
      // …and only ever a colorful role, never the muted neutral.
      for (final id in ['admins', 'editors', 'viewers', 'x', 'team-42']) {
        expect(GroupColor.auto(id), isNot(GroupColor.neutral));
      }
    });

    test('resolve returns the matching on-color for contrast', () {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF033B53));
      final primary = GroupColor.primary.resolve(scheme);
      expect(primary.background, scheme.primaryContainer);
      expect(primary.foreground, scheme.onPrimaryContainer);

      final neutral = GroupColor.neutral.resolve(scheme);
      expect(neutral.background, scheme.surfaceContainerHighest);
      expect(neutral.foreground, scheme.onSurfaceVariant);
    });
  });

  group('GroupListView', () {
    testWidgets('row menu opens and deletes through the confirm dialog', (
      tester,
    ) async {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GroupListView(controller: controller)),
        ),
      );

      // Opening the overflow menu must not throw — a ListTile inside a
      // PopupMenuItem crashes under IntrinsicWidth; MenuAnchor does not.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm dialog → commit the deletion.
      expect(find.text('Delete "Alpha"?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(controller.isEmpty, isTrue);
    });

    testWidgets('onDelete fires with the group after it is removed', (
      tester,
    ) async {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      addTearDown(controller.dispose);
      Group? deleted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupListView(
              controller: controller,
              onDelete: (g) => deleted = g,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // The confirmation still ran, the controller applied the removal, and the
      // callback fired with the deleted group.
      expect(controller.isEmpty, isTrue);
      expect(deleted?.id, 'a');
    });

    testWidgets('onEdit fires with the updated group after it is applied', (
      tester,
    ) async {
      final controller = GroupManagerController(
        groups: const [Group(id: 'a', name: 'Alpha')],
      );
      addTearDown(controller.dispose);
      Group? edited;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupListView(
              controller: controller,
              onEdit: (g) => edited = g,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Alpha Prime');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(controller.groupById('a')?.name, 'Alpha Prime');
      expect(edited?.name, 'Alpha Prime');
    });
  });

  group('GroupEditorDialog', () {
    testWidgets('blocks save on an empty name, then returns a new group', (
      tester,
    ) async {
      Group? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    result = await GroupEditorDialog.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Empty name fails validation and keeps the dialog open.
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.byType(GroupEditorDialog), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Admins');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, 'Admins');
      expect(result!.id, startsWith('group-'));
    });

    testWidgets('edit mode pre-fills and preserves the id', (tester) async {
      Group? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async => result = await GroupEditorDialog.show(
                  context,
                  initial: const Group(id: 'admins', name: 'Administrators'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Edit group'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Admins Renamed',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(result!.id, 'admins');
      expect(result!.name, 'Admins Renamed');
    });
  });

  group('GroupPicker', () {
    testWidgets('searches description and returns the selected ids', (
      tester,
    ) async {
      Set<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async => result = await GroupPicker.show(
                  context,
                  groups: const [
                    Group(id: 'a', name: 'Alpha', description: 'finance team'),
                    Group(id: 'b', name: 'Beta', description: 'design team'),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // A term only present in a description still finds the group.
      await tester.enterText(find.byType(SearchBar), 'finance');
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Done (1)'));
      await tester.pumpAndSettle();

      expect(result, {'a'});
    });

    testWidgets('destructive tints the confirm button and checkboxes with '
        'the error color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => GroupPicker.show(
                  context,
                  groups: const [Group(id: 'a', name: 'Alpha')],
                  destructive: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.text('Alpha')));
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.style?.backgroundColor?.resolve({}),
        theme.colorScheme.error,
      );
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.activeColor, theme.colorScheme.error);
    });
  });

  group('GroupBulkAssignmentDialog', () {
    testWidgets('frames the picker around the principal count', (tester) async {
      Set<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    result = await GroupBulkAssignmentDialog.show(
                      context,
                      groups: const [
                        Group(id: 'a', name: 'Alpha'),
                        Group(id: 'b', name: 'Beta'),
                      ],
                      principalCount: 12,
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Add groups to 12 users'), findsOneWidget);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add to 12 users'));
      await tester.pumpAndSettle();

      expect(result, {'a'});
    });

    testWidgets('showRemoval frames the picker around removing', (
      tester,
    ) async {
      Set<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    result = await GroupBulkAssignmentDialog.showRemoval(
                      context,
                      groups: const [
                        Group(id: 'a', name: 'Alpha'),
                        Group(id: 'b', name: 'Beta'),
                      ],
                      principalCount: 3,
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Remove groups from 3 users'), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Remove from 3 users'),
      );
      await tester.pumpAndSettle();

      expect(result, {'b'});
    });

    testWidgets('showRemoval excludes lockedIds from the offered groups', (
      tester,
    ) async {
      Set<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    result = await GroupBulkAssignmentDialog.showRemoval(
                      context,
                      groups: const [
                        Group(id: 'a', name: 'Alpha'),
                        Group(id: 'b', name: 'Beta'),
                      ],
                      principalCount: 2,
                      lockedIds: const {'a'},
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The locked group isn't offered at all — not even checked-and-disabled
      // — since a checked box here means "remove", and locking is supposed
      // to prevent removal, not guarantee it.
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Remove from 2 users'),
      );
      await tester.pumpAndSettle();

      expect(result, {'b'});
    });
  });

  group('GroupAssignmentField', () {
    testWidgets('removes a chip and reports the new selection', (tester) async {
      Set<String>? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupAssignmentField(
              groups: const [
                Group(id: 'a', name: 'Alpha'),
                Group(id: 'b', name: 'Beta'),
              ],
              selected: const {'a', 'b'},
              onChanged: (ids) => changed = ids,
            ),
          ),
        ),
      );
      expect(find.byType(InputChip), findsNWidgets(2));

      await tester.tap(find.byTooltip('Remove Alpha'));
      await tester.pumpAndSettle();
      expect(changed, {'b'});
    });

    testWidgets('disabled field hides the edit button and shows the hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroupAssignmentField(
              groups: [Group(id: 'a', name: 'Alpha')],
              selected: <String>{},
              onChanged: _noop,
              enabled: false,
              emptyHint: 'Nothing here',
            ),
          ),
        ),
      );
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.byTooltip('Edit groups'), findsNothing);
    });

    testWidgets('header button opens the picker and reports the selection', (
      tester,
    ) async {
      Set<String>? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupAssignmentField(
              groups: const [
                Group(id: 'a', name: 'Alpha'),
                Group(id: 'b', name: 'Beta'),
              ],
              selected: const <String>{},
              onChanged: (ids) => changed = ids,
              editLabel: 'Edit groups',
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit groups'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Done (1)'));
      await tester.pumpAndSettle();

      expect(changed, {'b'});
    });

    testWidgets('maxVisibleChips collapses overflow behind "+N more"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupAssignmentField(
              groups: const [
                Group(id: 'a', name: 'Alpha'),
                Group(id: 'b', name: 'Beta'),
                Group(id: 'c', name: 'Gamma'),
              ],
              selected: const {'a', 'b', 'c'},
              onChanged: _noop,
              maxVisibleChips: 2,
            ),
          ),
        ),
      );

      expect(find.byType(GroupChip), findsNWidgets(2));
      expect(find.text('+1 more'), findsOneWidget);

      await tester.tap(find.text('+1 more'));
      await tester.pumpAndSettle();

      expect(find.byType(GroupChip), findsNWidgets(3));
      expect(find.text('+1 more'), findsNothing);
      expect(find.text('Show less'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();

      expect(find.byType(GroupChip), findsNWidgets(2));
      expect(find.text('+1 more'), findsOneWidget);
    });

    testWidgets('transitions its size when a chip is removed', (tester) async {
      Widget fieldWith(Set<String> selected, {Duration? duration}) =>
          MaterialApp(
            home: Scaffold(
              body: GroupAssignmentField(
                groups: const [
                  Group(id: 'a', name: 'Alpha'),
                  Group(id: 'b', name: 'Beta'),
                  Group(id: 'c', name: 'Gamma'),
                ],
                selected: selected,
                onChanged: _noop,
                sizeAnimationDuration:
                    duration ??
                    GroupAssignmentField.defaultSizeAnimationDuration,
              ),
            ),
          );

      final chipArea = find
          .descendant(
            of: find.byType(GroupAssignmentField),
            matching: find.byType(AnimatedSize),
          )
          .first;

      await tester.pumpWidget(fieldWith(const {'a', 'b', 'c'}));
      final wideWidth = tester.getSize(chipArea).width;

      await tester.pumpWidget(fieldWith(const {'a'}));
      await tester.pump(const Duration(milliseconds: 16));
      final midWidth = tester.getSize(chipArea).width;

      await tester.pumpAndSettle();
      final narrowWidth = tester.getSize(chipArea).width;

      // Mid-flight the field is still between its old and new widths rather
      // than having snapped to the latter on the first frame.
      expect(narrowWidth, lessThan(wideWidth));
      expect(midWidth, greaterThan(narrowWidth));
      expect(midWidth, lessThanOrEqualTo(wideWidth));

      // Duration.zero opts out entirely: no animator in the tree, and the
      // chips land at their new width on the first frame.
      await tester.pumpWidget(fieldWith(const {'a', 'b', 'c'}));
      await tester.pumpAndSettle();
      await tester.pumpWidget(fieldWith(const {'a'}, duration: Duration.zero));
      await tester.pump();

      expect(find.byType(AnimatedSize), findsNothing);
      expect(tester.getSize(find.byType(Wrap)).width, narrowWidth);
    });

    testWidgets('skips the size transition when the platform asks for '
        'reduced motion', (tester) async {
      Widget fieldWith(Set<String> selected) => MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: GroupAssignmentField(
              groups: const [
                Group(id: 'a', name: 'Alpha'),
                Group(id: 'b', name: 'Beta'),
                Group(id: 'c', name: 'Gamma'),
              ],
              selected: selected,
              onChanged: _noop,
            ),
          ),
        ),
      );

      await tester.pumpWidget(fieldWith(const {'a', 'b', 'c'}));
      await tester.pumpAndSettle();

      await tester.pumpWidget(fieldWith(const {'a'}));
      await tester.pump();

      // The default duration is in force, but reduced motion overrides it:
      // no animator, and the chips are already at their settled width.
      expect(find.byType(AnimatedSize), findsNothing);
      final settled = tester.getSize(find.byType(Wrap)).width;
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Wrap)).width, settled);
    });

    testWidgets('maxVisibleChips is inert when the count fits', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupAssignmentField(
              groups: const [
                Group(id: 'a', name: 'Alpha'),
                Group(id: 'b', name: 'Beta'),
              ],
              selected: const {'a', 'b'},
              onChanged: _noop,
              maxVisibleChips: 5,
            ),
          ),
        ),
      );

      expect(find.byType(GroupChip), findsNWidgets(2));
      expect(find.textContaining('more'), findsNothing);
    });

    testWidgets('singleLine shows every chip when the row is wide enough', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: GroupAssignmentField(
                label: 'Ada Lovelace',
                groups: const [
                  Group(id: 'a', name: 'Alpha'),
                  Group(id: 'b', name: 'Beta'),
                  Group(id: 'c', name: 'Gamma'),
                ],
                selected: const {'a', 'b', 'c'},
                onChanged: _noop,
                singleLine: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GroupChip), findsNWidgets(3));
      expect(find.textContaining('more'), findsNothing);
      // Label, chips, and the edit button share one Row.
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('singleLine collapses to fit a narrow row, then expands', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: GroupAssignmentField(
                groups: const [
                  Group(id: 'a', name: 'Alpha'),
                  Group(id: 'b', name: 'Beta'),
                  Group(id: 'c', name: 'Gamma'),
                ],
                selected: const {'a', 'b', 'c'},
                onChanged: _noop,
                singleLine: true,
              ),
            ),
          ),
        ),
      );

      // Too narrow to fit every chip: at least one shows, the rest collapse.
      final visibleChips = tester.widgetList(find.byType(GroupChip)).length;
      expect(visibleChips, lessThan(3));
      expect(find.textContaining('more'), findsOneWidget);

      await tester.tap(find.textContaining('more'));
      await tester.pumpAndSettle();

      // Expanded: every chip renders, plus "Show less" to collapse again.
      expect(find.byType(GroupChip), findsNWidgets(3));
      expect(find.text('Show less'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();

      expect(tester.widgetList(find.byType(GroupChip)).length, visibleChips);
    });

    testWidgets('singleLine still honors an explicit maxVisibleChips cap', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: GroupAssignmentField(
                groups: const [
                  Group(id: 'a', name: 'Alpha'),
                  Group(id: 'b', name: 'Beta'),
                  Group(id: 'c', name: 'Gamma'),
                ],
                selected: const {'a', 'b', 'c'},
                onChanged: _noop,
                singleLine: true,
                maxVisibleChips: 1,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GroupChip), findsNWidgets(1));
      expect(find.text('+2 more'), findsOneWidget);
    });

    testWidgets('singleLine ellipsizes an overlong label rather than '
        'overflowing the row — even if that crowds out every real chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: GroupAssignmentField(
                label:
                    'A deliberately absurdly long member name that would '
                    'otherwise consume the entire row all by itself',
                groups: const [
                  Group(id: 'a', name: 'Alpha'),
                  Group(id: 'b', name: 'Beta'),
                  Group(id: 'c', name: 'Gamma'),
                ],
                selected: const {'a', 'b', 'c'},
                onChanged: _noop,
                singleLine: true,
              ),
            ),
          ),
        ),
      );

      // The label is ellipsized rather than rendered at full intrinsic width…
      final label = tester.widget<Text>(find.textContaining('A deliberately'));
      expect(label.overflow, TextOverflow.ellipsis);
      expect(label.maxLines, 1);
      // …so the row never overflows, even though it crowds every real chip
      // out in favor of just the overflow chip — that's an acceptable
      // outcome, unlike a broken layout.
      expect(find.byType(GroupChip), findsNothing);
      expect(find.text('+3 more'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('GroupManagerView', () {
    testWidgets('swaps the create button for a search bar once populated', (
      tester,
    ) async {
      final controller = GroupManagerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GroupManagerView(controller: controller)),
        ),
      );

      // Empty catalog: standalone create button, no search bar.
      expect(find.byType(SearchBar), findsNothing);
      expect(find.widgetWithText(FilledButton, 'New group'), findsOneWidget);

      controller.addGroup(const Group(id: 'a', name: 'Alpha'));
      await tester.pumpAndSettle();

      // Populated: the search bar appears and hosts the create action.
      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('onCreate fires with the group after it is added', (
      tester,
    ) async {
      final controller = GroupManagerController();
      addTearDown(controller.dispose);
      Group? created;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupManagerView(
              controller: controller,
              onCreate: (g) => created = g,
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'New group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Admins');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      // The dialog ran, the controller has the new group, and the callback
      // fired with it.
      expect(controller.groups.single.name, 'Admins');
      expect(created?.name, 'Admins');
    });
  });
}

void _noop(Set<String> _) {}

import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = <Group>[
  Group(id: 'admin', name: 'Admin'),
  Group(id: 'edit', name: 'Editors'),
];

const _roster = <Principal>[
  Principal(id: 'ada', name: 'Ada Lovelace', description: 'ada@example.com'),
  Principal(
    id: 'grace',
    name: 'Grace Hopper',
    description: 'grace@example.com',
  ),
  Principal(id: 'linus', name: 'Linus Torvalds'),
];

GroupManagerController _controller({Map<String, Set<String>>? assignments}) {
  final controller = GroupManagerController(
    groups: _catalog,
    assignments: assignments ?? const {},
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('GroupManagerController membersOf', () {
    test(
      'reports the principals holding a group, and none for an empty one',
      () {
        final c = _controller(
          assignments: {
            'ada': {'admin', 'edit'},
            'grace': {'edit'},
          },
        );

        expect(c.membersOf('edit'), <String>{'ada', 'grace'});
        expect(c.membersOf('admin'), <String>{'ada'});
        expect(c.membersOf('nope'), isEmpty);
        expect(c.memberCount('edit'), 2);
        expect(c.memberCount('admin'), 1);
      },
    );

    test('is the exact inverse of groupsFor', () {
      final c = _controller(
        assignments: {
          'ada': {'admin', 'edit'},
          'grace': {'edit'},
        },
      );

      for (final group in _catalog) {
        for (final id in <String>['ada', 'grace', 'linus']) {
          expect(
            c.membersOf(group.id).contains(id),
            c.groupsFor(id).contains(group.id),
            reason: '${group.id} / $id disagree between the two directions',
          );
        }
      }
    });

    test('returns an unmodifiable snapshot', () {
      final c = _controller(
        assignments: {
          'ada': {'edit'},
        },
      );
      expect(() => c.membersOf('edit').add('grace'), throwsUnsupportedError);
    });
  });

  group('GroupManagerController setMembers', () {
    test('adds and removes to match the given set', () {
      final c = _controller(
        assignments: {
          'ada': {'edit'},
          'grace': {'edit'},
        },
      );

      c.setMembers('edit', {'grace', 'linus'});

      expect(c.membersOf('edit'), <String>{'grace', 'linus'});
      expect(c.groupsFor('ada'), isEmpty);
    });

    test("rewrites one group's column without touching other memberships", () {
      final c = _controller(
        assignments: {
          'ada': {'admin', 'edit'},
        },
      );

      c.setMembers('edit', const <String>{});

      // Dropped from Editors, but still an Admin — unlike setAssignments,
      // which would have replaced the principal's whole membership.
      expect(c.membersOf('edit'), isEmpty);
      expect(c.groupsFor('ada'), <String>{'admin'});
    });

    test('drops a principal left with no memberships at all', () {
      final c = _controller(
        assignments: {
          'ada': {'edit'},
        },
      );

      c.setMembers('edit', const <String>{});

      expect(c.groupsFor('ada'), isEmpty);
      expect(c.membersOf('edit'), isEmpty);
    });

    test('ignores an unknown group id', () {
      final c = _controller();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.setMembers('nope', {'ada'});

      expect(c.groupsFor('ada'), isEmpty);
      expect(notifications, 0);
    });

    test(
      'notifies once for the whole batch, and not at all when unchanged',
      () {
        final c = _controller(
          assignments: {
            'ada': {'edit'},
          },
        );
        var notifications = 0;
        c.addListener(() => notifications++);

        c.setMembers('edit', {'grace', 'linus'});
        expect(notifications, 1);

        c.setMembers('edit', {'grace', 'linus'});
        expect(notifications, 1);
      },
    );
  });

  group('MemberPicker', () {
    Future<Set<String>?> openAndConfirm(
      WidgetTester tester, {
      Set<String> initiallySelected = const <String>{},
      Set<String> lockedIds = const <String>{},
      String? tapName,
    }) async {
      Set<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await MemberPicker.show(
                    context,
                    roster: _roster,
                    initiallySelected: initiallySelected,
                    lockedIds: lockedIds,
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
      if (tapName != null) {
        await tester.tap(find.text(tapName));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.textContaining('Done ('));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('returns the selected principal ids', (tester) async {
      final result = await openAndConfirm(tester, tapName: 'Grace Hopper');
      expect(result, <String>{'grace'});
    });

    testWidgets('seeds from the current membership and toggles it off', (
      tester,
    ) async {
      final result = await openAndConfirm(
        tester,
        initiallySelected: const {'ada', 'grace'},
        tapName: 'Ada Lovelace',
      );
      expect(result, <String>{'grace'});
    });

    testWidgets('locked member is checked, disabled, and always returned', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MemberPicker.show(
                  context,
                  roster: _roster,
                  lockedIds: const {'ada'},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final tile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Ada Lovelace'),
      );
      expect(tile.value, isTrue);
      expect(tile.enabled, isFalse);
      expect(find.byTooltip("Required — can't be removed"), findsOneWidget);
      // Counts toward the confirm total even with no interaction.
      expect(find.text('Done (1)'), findsOneWidget);
    });

    testWidgets('searches name and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MemberPicker.show(context, roster: _roster),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'grace@');
      await tester.pumpAndSettle();
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);

      await tester.enterText(find.byType(SearchBar), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No members match "zzz".'), findsOneWidget);
    });
  });

  group('MemberAssignmentField', () {
    testWidgets('renders members as chips and removes one', (tester) async {
      Set<String>? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberAssignmentField(
              label: 'Editors',
              roster: _roster,
              selected: const {'ada', 'grace'},
              onChanged: (ids) => changed = ids,
            ),
          ),
        ),
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Linus Torvalds'), findsNothing);

      await tester.tap(find.byTooltip('Remove Ada Lovelace'));
      await tester.pump();

      expect(changed, <String>{'grace'});
    });

    testWidgets('locked member renders without a delete affordance and '
        'survives removing another chip', (tester) async {
      Set<String>? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberAssignmentField(
              roster: _roster,
              selected: const {'grace'},
              lockedIds: const {'ada'},
              onChanged: (ids) => changed = ids,
            ),
          ),
        ),
      );

      // Shown despite being absent from `selected`, as a non-removable chip.
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.byTooltip('Remove Ada Lovelace'), findsNothing);
      expect(find.byTooltip("Required — can't be removed"), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Grace Hopper'));
      await tester.pump();

      expect(changed, <String>{'ada'});
    });

    testWidgets('edit button opens the picker and reports the new membership', (
      tester,
    ) async {
      Set<String>? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberAssignmentField(
              roster: _roster,
              selected: const {'ada'},
              onChanged: (ids) => changed = ids,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit members'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Linus Torvalds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done (2)'));
      await tester.pumpAndSettle();

      expect(changed, <String>{'ada', 'linus'});
    });
  });

  group('GroupMembersView', () {
    Future<GroupManagerController> pumpView(
      WidgetTester tester, {
      Map<String, Set<String>>? assignments,
      Set<String> lockedMemberIds = const <String>{},
      ValueChanged<Set<String>>? onMembersAdded,
      ValueChanged<Set<String>>? onMembersRemoved,
      String groupId = 'edit',
    }) async {
      final controller = _controller(assignments: assignments);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupMembersView(
              groupId: groupId,
              roster: _roster,
              controller: controller,
              lockedMemberIds: lockedMemberIds,
              onMembersAdded: onMembersAdded,
              onMembersRemoved: onMembersRemoved,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('lists the group members, and only them', (tester) async {
      await pumpView(
        tester,
        assignments: {
          'ada': {'edit'},
          'linus': {'admin'},
        },
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Linus Torvalds'), findsNothing);
    });

    testWidgets('empty group shows the hint and a standalone edit button', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('No members yet'), findsOneWidget);
      // No search bar to host the action, so it stands alone.
      expect(find.byType(SearchBar), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Edit members'), findsOneWidget);
    });

    testWidgets('editing members applies the picker result and fires both '
        'callbacks with what actually changed', (tester) async {
      Set<String>? added;
      Set<String>? removed;
      final controller = await pumpView(
        tester,
        assignments: {
          'ada': {'admin', 'edit'},
        },
        onMembersAdded: (ids) => added = ids,
        onMembersRemoved: (ids) => removed = ids,
      );

      await tester.tap(find.byTooltip('Edit members'));
      await tester.pumpAndSettle();

      // Ada is pre-checked as the current member; swap her for Grace. Scoped
      // to the picker's rows — the list underneath shows her name too.
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Ada Lovelace'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Grace Hopper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done (1)'));
      await tester.pumpAndSettle();

      expect(controller.membersOf('edit'), <String>{'grace'});
      // Ada keeps Admin — only this group's column was rewritten.
      expect(controller.groupsFor('ada'), <String>{'admin'});
      expect(added, <String>{'grace'});
      expect(removed, <String>{'ada'});
    });

    testWidgets('per-row remove confirms first, then unassigns', (
      tester,
    ) async {
      Set<String>? removed;
      final controller = await pumpView(
        tester,
        assignments: {
          'ada': {'admin', 'edit'},
        },
        onMembersRemoved: (ids) => removed = ids,
      );

      await tester.tap(find.byTooltip('Remove Ada Lovelace'));
      await tester.pumpAndSettle();

      // Cancelling leaves the membership alone.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.membersOf('edit'), <String>{'ada'});
      expect(removed, isNull);

      await tester.tap(find.byTooltip('Remove Ada Lovelace'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(controller.membersOf('edit'), isEmpty);
      expect(controller.groupsFor('ada'), <String>{'admin'});
      expect(removed, <String>{'ada'});
    });

    testWidgets('bulk removal acts on every checked member', (tester) async {
      final controller = await pumpView(
        tester,
        assignments: {
          'ada': {'edit'},
          'grace': {'edit'},
          'linus': {'edit'},
        },
      );

      // Select all via the BulkSelectionBar's tristate checkbox.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from group'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(controller.membersOf('edit'), isEmpty);
    });

    testWidgets(
      'locked member offers no remove action and cannot be selected',
      (tester) async {
        await pumpView(
          tester,
          assignments: {
            'ada': {'edit'},
            'grace': {'edit'},
          },
          lockedMemberIds: const {'ada'},
        );

        expect(find.byTooltip('Remove Ada Lovelace'), findsNothing);
        expect(find.byTooltip("Locked — can't be removed"), findsOneWidget);
        // Grace is still removable.
        expect(find.byTooltip('Remove Grace Hopper'), findsOneWidget);

        // "All" selects only the unlocked member.
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
      },
    );

    testWidgets('a member missing from the roster is surfaced, not hidden', (
      tester,
    ) async {
      await pumpView(
        tester,
        assignments: {
          'ghost': {'edit'},
        },
      );

      expect(find.text('ghost'), findsOneWidget);
      expect(find.text('Not in the roster'), findsOneWidget);
    });

    testWidgets('a group deleted out from under the view says so', (
      tester,
    ) async {
      await pumpView(tester, groupId: 'gone');
      expect(find.text('This group no longer exists'), findsOneWidget);
    });
  });
}

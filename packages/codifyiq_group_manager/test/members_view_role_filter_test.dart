import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _roster = <Principal>[
  Principal(id: 'ada', name: 'Ada Lovelace'),
  Principal(id: 'grace', name: 'Grace Hopper'),
  Principal(id: 'linus', name: 'Linus Torvalds'),
];

const _roles = <AssignmentRole>[
  AssignmentRole(id: 'owner', label: 'Owner'),
  AssignmentRole(id: 'member', label: 'Member'),
];

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

/// A member's row, by name — not the same text elsewhere on screen.
Finder _row(String name) => find.widgetWithText(ListTile, name);

void main() {
  /// Replaces the host's role map from outside the view — a sync, or another
  /// admin's edit. Set by each [pumpView].
  late void Function(Map<String, String> rolesById) setHostRoles;

  /// Pumps the view with a caller that applies role changes to its own map,
  /// as a real host would. Returns the ids each bulk removal reported.
  Future<List<Set<String>>> pumpView(
    WidgetTester tester, {
    List<AssignmentRole> roles = _roles,
    Map<String, String> rolesById = const {
      'ada': 'owner',
      'grace': 'member',
      'linus': 'member',
    },
  }) async {
    final removed = <Set<String>>[];
    final controller = GroupManagerController(
      groups: const [Group(id: 'edit', name: 'Editors')],
      assignments: const {
        'ada': {'edit'},
        'grace': {'edit'},
        'linus': {'edit'},
      },
    );
    addTearDown(controller.dispose);
    var roleOf = rolesById;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostRoles = (rolesById) => setState(() => roleOf = rolesById);
              return GroupMembersView(
                groupId: 'edit',
                roster: _roster,
                controller: controller,
                roles: roles,
                rolesById: roleOf,
                onRoleChanged: (ids, roleId) => setState(
                  () => roleOf = {...roleOf, for (final id in ids) id: roleId},
                ),
                onMembersRemoved: removed.add,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return removed;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('GroupMembersView role filter', () {
    testWidgets('roles omitted shows no filter', (tester) async {
      await pumpView(tester, roles: const []);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(_row('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('narrows to one role and back to all', (tester) async {
      await pumpView(tester);
      expect(tester.widget<ChoiceChip>(_chip('All members')).selected, isTrue);

      await tapAndSettle(tester, _chip('Owner'));
      expect(tester.widget<ChoiceChip>(_chip('Owner')).selected, isTrue);
      expect(_row('Ada Lovelace'), findsOneWidget);
      expect(_row('Grace Hopper'), findsNothing);
      expect(_row('Linus Torvalds'), findsNothing);

      await tapAndSettle(tester, _chip('All members'));
      expect(_row('Grace Hopper'), findsOneWidget);
      expect(_row('Linus Torvalds'), findsOneWidget);
    });

    testWidgets('tapping the selected role clears the filter', (tester) async {
      await pumpView(tester);

      await tapAndSettle(tester, _chip('Owner'));
      await tapAndSettle(tester, _chip('Owner'));

      expect(tester.widget<ChoiceChip>(_chip('All members')).selected, isTrue);
      expect(_row('Grace Hopper'), findsOneWidget);
    });

    testWidgets('combines with the search', (tester) async {
      await pumpView(tester);

      await tapAndSettle(tester, _chip('Member'));
      await tester.enterText(find.byType(SearchBar), 'grace');
      await tester.pumpAndSettle();

      expect(_row('Grace Hopper'), findsOneWidget);
      expect(_row('Linus Torvalds'), findsNothing);
      expect(_row('Ada Lovelace'), findsNothing);
    });

    testWidgets('select all and bulk removal act only on the members shown', (
      tester,
    ) async {
      final removed = await pumpView(tester);

      await tapAndSettle(tester, _chip('Member'));
      await tapAndSettle(tester, find.byType(Checkbox));
      expect(find.text('2 selected'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Remove from group'));
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Remove'));

      expect(removed, [
        {'grace', 'linus'},
      ]);
    });

    testWidgets('switching the filter drops selected members it hides', (
      tester,
    ) async {
      await pumpView(tester);

      // Select everyone, then narrow to owners: only Ada stays selected.
      await tapAndSettle(tester, find.byType(Checkbox));
      expect(find.text('3 selected'), findsOneWidget);
      await tapAndSettle(tester, _chip('Owner'));

      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('a role changed by the host deselects the member it hides', (
      tester,
    ) async {
      final removed = await pumpView(tester);

      await tapAndSettle(tester, _chip('Member'));
      await tapAndSettle(tester, find.byType(Checkbox));
      expect(find.text('2 selected'), findsOneWidget);

      setHostRoles(const {'ada': 'owner', 'grace': 'owner', 'linus': 'member'});
      await tester.pumpAndSettle();
      expect(_row('Grace Hopper'), findsNothing);
      expect(find.text('1 selected'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Remove from group'));
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Remove'));
      expect(removed, [
        {'linus'},
      ]);
    });

    testWidgets('a role change moves the member out of the filtered list', (
      tester,
    ) async {
      await pumpView(tester);

      await tapAndSettle(tester, _chip('Member'));
      await tapAndSettle(
        tester,
        find.descendant(
          of: _row('Grace Hopper'),
          matching: find.widgetWithText(TextButton, 'Member'),
        ),
      );
      await tapAndSettle(tester, find.widgetWithText(MenuItemButton, 'Owner'));

      expect(_row('Grace Hopper'), findsNothing);
      expect(_row('Linus Torvalds'), findsOneWidget);
    });

    testWidgets('an empty filter says so in terms of the role', (tester) async {
      await pumpView(
        tester,
        rolesById: const {'ada': 'member', 'grace': 'member'},
      );

      await tapAndSettle(tester, _chip('Owner'));
      expect(find.text('No members with the role "Owner"'), findsOneWidget);

      await tester.enterText(find.byType(SearchBar), 'zzz');
      await tester.pumpAndSettle();
      expect(
        find.text('No members with the role "Owner" match "zzz"'),
        findsOneWidget,
      );
    });

    testWidgets('chips are announced as a selectable role filter', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpView(tester);

      expect(find.bySemanticsLabel('Filter by role'), findsOneWidget);
      expect(
        tester.getSemantics(_chip('All members')),
        matchesSemantics(
          label: 'All members',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });
}

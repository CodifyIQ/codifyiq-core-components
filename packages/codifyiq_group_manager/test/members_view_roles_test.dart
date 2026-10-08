import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = <Group>[Group(id: 'edit', name: 'Editors')];

const _roster = <Principal>[
  Principal(id: 'ada', name: 'Ada Lovelace'),
  Principal(id: 'grace', name: 'Grace Hopper'),
  Principal(id: 'linus', name: 'Linus Torvalds'),
];

const _roles = <AssignmentRole>[
  AssignmentRole(id: 'owner', label: 'Owner', description: 'Can manage'),
  AssignmentRole(id: 'member', label: 'Member'),
];

/// The check beside the current role in an open role menu — not the check
/// glyph a selected member's avatar swaps to.
final Finder _menuCheck = find.descendant(
  of: find.byType(MenuItemButton),
  matching: find.byIcon(Icons.check),
);

/// The role chevron on a member row — not the selection bar's own drop-down.
final Finder _rowChevron = find.descendant(
  of: find.byType(ListTile),
  matching: find.byIcon(Icons.arrow_drop_down),
);

void main() {
  Future<GroupManagerController> pumpView(
    WidgetTester tester, {
    Map<String, Set<String>> assignments = const {
      'ada': {'edit'},
      'grace': {'edit'},
    },
    List<AssignmentRole> roles = _roles,
    Map<String, String> rolesById = const {'ada': 'owner', 'grace': 'member'},
    String? defaultRoleId,
    Set<String> lockedMemberIds = const <String>{},
    void Function(Set<String> ids, String roleId)? onRoleChanged,
    ValueChanged<Set<String>>? onMembersAdded,
  }) async {
    final controller = GroupManagerController(
      groups: _catalog,
      assignments: assignments,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupMembersView(
            groupId: 'edit',
            roster: _roster,
            controller: controller,
            roles: roles,
            rolesById: rolesById,
            defaultRoleId: defaultRoleId,
            lockedMemberIds: lockedMemberIds,
            onRoleChanged: onRoleChanged,
            onMembersAdded: onMembersAdded,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  group('GroupMembersView roles', () {
    testWidgets('roles omitted renders no role text, menu, or bulk action', (
      tester,
    ) async {
      await pumpView(tester, roles: const [], onRoleChanged: (_, _) {});

      expect(find.text('Owner'), findsNothing);
      expect(find.text('Member'), findsNothing);
      expect(_rowChevron, findsNothing);
      expect(find.byTooltip('Set role'), findsNothing);
      expect(find.byTooltip('Remove Ada Lovelace'), findsOneWidget);
    });

    testWidgets('each row shows its role and changes it through the menu', (
      tester,
    ) async {
      Set<String>? ids;
      String? roleId;
      await pumpView(
        tester,
        onRoleChanged: (i, r) {
          ids = i;
          roleId = r;
        },
      );

      expect(find.widgetWithText(TextButton, 'Owner'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Member'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Owner'));
      await tester.pumpAndSettle();

      // Menu lists every role with the current one checked and the
      // description as a secondary line.
      expect(find.byType(MenuItemButton), findsNWidgets(2));
      expect(find.text('Can manage'), findsOneWidget);
      expect(_menuCheck, findsOneWidget);

      await tester.tap(find.widgetWithText(MenuItemButton, 'Member'));
      await tester.pumpAndSettle();

      expect(ids, <String>{'ada'});
      expect(roleId, 'member');
    });

    testWidgets('picking the current role again reports nothing', (
      tester,
    ) async {
      var calls = 0;
      await pumpView(tester, onRoleChanged: (_, _) => calls++);

      await tester.tap(find.widgetWithText(TextButton, 'Owner'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Owner'));
      await tester.pumpAndSettle();

      expect(calls, 0);
    });

    testWidgets('a member missing from rolesById can still be given one', (
      tester,
    ) async {
      Set<String>? ids;
      String? roleId;
      await pumpView(
        tester,
        rolesById: const {'ada': 'owner'},
        onRoleChanged: (i, r) {
          ids = i;
          roleId = r;
        },
      );

      await tester.tap(find.widgetWithText(TextButton, 'Set role'));
      await tester.pumpAndSettle();
      expect(_menuCheck, findsNothing);

      await tester.tap(find.widgetWithText(MenuItemButton, 'Member'));
      await tester.pumpAndSettle();

      expect(ids, <String>{'grace'});
      expect(roleId, 'member');
    });

    testWidgets('an unknown role id shows the raw id', (tester) async {
      await pumpView(
        tester,
        rolesById: const {'ada': 'owner', 'grace': 'guest'},
        onRoleChanged: (_, _) {},
      );

      expect(find.widgetWithText(TextButton, 'guest'), findsOneWidget);
    });

    testWidgets('locked row shows its role read-only', (tester) async {
      await pumpView(
        tester,
        lockedMemberIds: const {'ada'},
        onRoleChanged: (_, _) {},
      );

      expect(find.text('Owner'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Owner'), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      // Grace is unlocked and still changeable.
      expect(find.widgetWithText(TextButton, 'Member'), findsOneWidget);
    });

    testWidgets('without onRoleChanged roles are display-only', (tester) async {
      await pumpView(tester);

      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(_rowChevron, findsNothing);

      // Select everyone: no bulk "Set role" action either.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Set role'), findsNothing);
    });

    testWidgets('bulk "Set role" applies one role to every selected member', (
      tester,
    ) async {
      Set<String>? ids;
      String? roleId;
      await pumpView(
        tester,
        onRoleChanged: (i, r) {
          ids = i;
          roleId = r;
        },
      );

      // Select all via the BulkSelectionBar's tristate checkbox.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Set role'));
      await tester.pumpAndSettle();
      // Mixed selection: nothing checked.
      expect(_menuCheck, findsNothing);

      await tester.tap(find.widgetWithText(MenuItemButton, 'Owner'));
      await tester.pumpAndSettle();

      expect(ids, <String>{'ada', 'grace'});
      expect(roleId, 'owner');
      // Selection is cleared once applied.
      expect(find.text('No members selected'), findsOneWidget);
    });

    testWidgets('bulk menu checks the role the whole selection shares', (
      tester,
    ) async {
      await pumpView(
        tester,
        rolesById: const {'ada': 'member', 'grace': 'member'},
        onRoleChanged: (_, _) {},
      );

      // Select all via the BulkSelectionBar's tristate checkbox.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Set role'));
      await tester.pumpAndSettle();

      expect(_menuCheck, findsOneWidget);
    });

    testWidgets('members added through the picker get defaultRoleId', (
      tester,
    ) async {
      final log = <String>[];
      final controller = await pumpView(
        tester,
        defaultRoleId: 'member',
        onMembersAdded: (ids) => log.add('added:${ids.join(',')}'),
        onRoleChanged: (ids, roleId) =>
            log.add('role:${ids.join(',')}:$roleId'),
      );

      await tester.tap(find.byTooltip('Edit members'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Linus Torvalds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done (3)'));
      await tester.pumpAndSettle();

      expect(controller.membersOf('edit'), <String>{'ada', 'grace', 'linus'});
      expect(log, ['added:linus', 'role:linus:member']);
    });

    testWidgets('no defaultRoleId leaves new members role-less', (
      tester,
    ) async {
      var roleCalls = 0;
      await pumpView(tester, onRoleChanged: (_, _) => roleCalls++);

      await tester.tap(find.byTooltip('Edit members'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Linus Torvalds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done (3)'));
      await tester.pumpAndSettle();

      expect(roleCalls, 0);
      expect(find.widgetWithText(TextButton, 'Set role'), findsOneWidget);
    });

    testWidgets('defaultRoleId must be one of roles', (tester) async {
      await pumpView(tester, defaultRoleId: 'nope');
      expect(tester.takeException(), isAssertionError);
    });
  });
}

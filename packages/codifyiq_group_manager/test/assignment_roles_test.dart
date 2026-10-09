import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = <Group>[
  Group(id: 'admin', name: 'Admin'),
  Group(id: 'edit', name: 'Editors'),
  Group(id: 'ops', name: 'Ops'),
];

const _roster = <Principal>[
  Principal(id: 'ada', name: 'Ada Lovelace'),
  Principal(id: 'grace', name: 'Grace Hopper'),
];

const _roles = <AssignmentRole>[
  AssignmentRole(id: 'view', label: 'Can view'),
  AssignmentRole(id: 'edit', label: 'Can edit'),
  AssignmentRole(
    id: 'manage',
    label: 'Can manage',
    description: 'Can edit and reshare',
  ),
];

const _memberRoles = <AssignmentRole>[
  AssignmentRole(id: 'owner', label: 'Owner'),
  AssignmentRole(id: 'member', label: 'Member'),
];

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('AssignmentRole equality is by value', () {
    const a = AssignmentRole(id: 'edit', label: 'Can edit', description: 'x');
    const b = AssignmentRole(id: 'edit', label: 'Can edit', description: 'x');
    const c = AssignmentRole(id: 'edit', label: 'Can edit');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(a.toString(), 'AssignmentRole(id: edit, label: Can edit)');
  });

  group('GroupAssignmentField roles', () {
    testWidgets('roles omitted renders no role text or chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          GroupAssignmentField(
            groups: _catalog,
            selected: const {'edit'},
            rolesById: const {'edit': 'edit'},
            onChanged: (_) {},
            onRoleChanged: (_, _) {},
          ),
        ),
      );

      expect(find.text('Editors'), findsOneWidget);
      expect(find.text('Can edit'), findsNothing);
      expect(find.text(' · '), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
      expect(find.byType(MenuAnchor), findsNothing);
    });

    testWidgets('chip shows its role label', (tester) async {
      await tester.pumpWidget(
        _app(
          GroupAssignmentField(
            groups: _catalog,
            selected: const {'edit'},
            roles: _roles,
            rolesById: const {'edit': 'manage'},
            onChanged: (_) {},
            onRoleChanged: (_, _) {},
          ),
        ),
      );

      expect(find.text('Editors'), findsOneWidget);
      expect(find.text('Can manage'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      // The chip reads as "<name>, <role>, change role" (after the group
      // avatar's initial), and the chip itself is the button.
      expect(
        find.bySemanticsLabel(RegExp('Editors, Can manage, change role\$')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byType(InputChip)),
        matchesSemantics(
          label: 'E\nEditors, Can manage, change role',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
        ),
      );
    });

    testWidgets('tapping the role opens the menu and picking reports it', (
      tester,
    ) async {
      final changes = <(String, String)>[];
      await tester.pumpWidget(
        _app(
          GroupAssignmentField(
            groups: _catalog,
            selected: const {'edit'},
            roles: _roles,
            rolesById: const {'edit': 'edit'},
            onChanged: (_) {},
            onRoleChanged: (id, roleId) => changes.add((id, roleId)),
          ),
        ),
      );

      await tester.tap(find.byType(InputChip));
      await tester.pumpAndSettle();

      // Every role is offered, the current one checked, with descriptions.
      expect(find.byType(MenuItemButton), findsNWidgets(3));
      expect(find.text('Can view'), findsOneWidget);
      expect(find.text('Can edit and reshare'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(MenuItemButton, 'Can edit'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Can manage'));
      await tester.pumpAndSettle();

      expect(changes, [('edit', 'manage')]);
      expect(find.byType(MenuItemButton), findsNothing);
    });

    testWidgets('re-picking the current role reports nothing', (tester) async {
      final changes = <(String, String)>[];
      await tester.pumpWidget(
        _app(
          GroupAssignmentField(
            groups: _catalog,
            selected: const {'edit'},
            roles: _roles,
            rolesById: const {'edit': 'view'},
            onChanged: (_) {},
            onRoleChanged: (id, roleId) => changes.add((id, roleId)),
          ),
        ),
      );

      await tester.tap(find.byType(InputChip));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Can view'));
      await tester.pumpAndSettle();

      expect(changes, isEmpty);
    });

    testWidgets('locked chip shows its role but cannot change it', (
      tester,
    ) async {
      final changes = <(String, String)>[];
      await tester.pumpWidget(
        _app(
          GroupAssignmentField(
            groups: _catalog,
            selected: const {'admin'},
            lockedIds: const {'admin'},
            roles: _roles,
            rolesById: const {'admin': 'manage'},
            onChanged: (_) {},
            onRoleChanged: (id, roleId) => changes.add((id, roleId)),
          ),
        ),
      );

      expect(find.text('Can manage'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

      await tester.tap(find.byType(Chip));
      await tester.pumpAndSettle();

      expect(find.byType(MenuItemButton), findsNothing);
      expect(changes, isEmpty);
    });

    testWidgets('disabled field shows roles read-only', (tester) async {
      await tester.pumpWidget(
        _app(
          GroupAssignmentField(
            groups: _catalog,
            selected: const {'edit'},
            enabled: false,
            roles: _roles,
            rolesById: const {'edit': 'edit'},
            onChanged: (_) {},
            onRoleChanged: (_, _) {},
          ),
        ),
      );

      expect(find.text('Can edit'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets(
      'id missing from rolesById shows no role but can be given one',
      (tester) async {
        final changes = <(String, String)>[];
        await tester.pumpWidget(
          _app(
            GroupAssignmentField(
              groups: _catalog,
              selected: const {'edit', 'ops'},
              roles: _roles,
              rolesById: const {'edit': 'edit'},
              onChanged: (_) {},
              onRoleChanged: (id, roleId) => changes.add((id, roleId)),
            ),
          ),
        );

        expect(find.text('Ops'), findsOneWidget);
        expect(find.text('Can edit'), findsOneWidget);
        // Only the Editors chip shows a role, but both chips offer the menu.
        expect(find.text(' · '), findsOneWidget);
        expect(find.byIcon(Icons.arrow_drop_down), findsNWidgets(2));
        expect(
          find.bySemanticsLabel(RegExp(r'Ops, change role$')),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(InputChip, 'Ops'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check), findsNothing);
        await tester.tap(find.text('Can view'));
        await tester.pumpAndSettle();

        expect(changes, [('ops', 'view')]);
      },
    );

    testWidgets('unknown role id shows the raw id and can still change', (
      tester,
    ) async {
      final changes = <(String, String)>[];
      await tester.pumpWidget(
        _app(
          GroupAssignmentField(
            groups: _catalog,
            selected: const {'edit'},
            roles: _roles,
            rolesById: const {'edit': 'legacy'},
            onChanged: (_) {},
            onRoleChanged: (id, roleId) => changes.add((id, roleId)),
          ),
        ),
      );

      expect(find.text('legacy'), findsOneWidget);
      await tester.tap(find.byType(InputChip));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsNothing);
      await tester.tap(find.text('Can view'));
      await tester.pumpAndSettle();

      expect(changes, [('edit', 'view')]);
    });

    testWidgets('picker adds report onChanged then the default role', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _app(
          GroupAssignmentField(
            groups: _catalog,
            selected: const {'edit'},
            roles: _roles,
            rolesById: const {'edit': 'manage'},
            defaultRoleId: 'view',
            onChanged: (ids) => calls.add('changed ${ids.length}'),
            onRoleChanged: (id, roleId) => calls.add('role $id $roleId'),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit groups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admin'));
      await tester.tap(find.text('Ops'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done (3)'));
      await tester.pumpAndSettle();

      // The already-selected group keeps its role; only new ids get one.
      expect(calls, ['changed 3', 'role admin view', 'role ops view']);
    });

    testWidgets('a long role label pushes a chip behind "+N more"', (
      tester,
    ) async {
      Widget field({required bool withRoles}) => _app(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: GroupAssignmentField(
              groups: _catalog,
              selected: const {'admin', 'edit', 'ops'},
              singleLine: true,
              sizeAnimationDuration: Duration.zero,
              roles: withRoles
                  ? const [
                      AssignmentRole(id: 'x', label: 'Can manage everything'),
                    ]
                  : const [],
              rolesById: const {'admin': 'x'},
              onChanged: (_) {},
              onRoleChanged: (_, _) {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(field(withRoles: false));
      expect(find.textContaining('more'), findsNothing);

      await tester.pumpWidget(field(withRoles: true));
      await tester.pump();
      expect(find.textContaining('more'), findsOneWidget);
    });
  });

  group('PrincipalChip and MemberAssignmentField roles', () {
    testWidgets('standalone PrincipalChip shows a display-only role', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const PrincipalChip(
            principal: Principal(id: 'a', name: 'Ada'),
            roleLabel: 'Owner',
          ),
        ),
      );

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('member chip shows its role and the menu changes it', (
      tester,
    ) async {
      final changes = <(String, String)>[];
      await tester.pumpWidget(
        _app(
          MemberAssignmentField(
            roster: _roster,
            selected: const {'ada', 'grace'},
            roles: _memberRoles,
            rolesById: const {'ada': 'owner', 'grace': 'member'},
            onChanged: (_) {},
            onRoleChanged: (id, roleId) => changes.add((id, roleId)),
          ),
        ),
      );

      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Grace Hopper, Member, change role'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(InputChip, 'Grace Hopper'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Owner'));
      await tester.pumpAndSettle();

      expect(changes, [('grace', 'owner')]);
    });
  });
}

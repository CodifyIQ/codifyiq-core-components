import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _roster = <Principal>[
  Principal(id: 'ada', name: 'Ada Lovelace', description: 'Engineering'),
  Principal(id: 'grace', name: 'Grace Hopper'),
  Principal(id: 'linus', name: 'Linus Torvalds'),
];

const _roles = <AssignmentRole>[
  AssignmentRole(id: 'owner', label: 'Billing administrator'),
  AssignmentRole(id: 'member', label: 'Member'),
];

/// [text] on a member row — not a role filter chip with the same label.
Finder _rowText(String text) =>
    find.descendant(of: find.byType(ListTile), matching: find.text(text));

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    double width, {
    List<AssignmentRole> roles = _roles,
    void Function(Set<String> ids, String roleId)? onRoleChanged,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = GroupManagerController(
      groups: const [Group(id: 'edit', name: 'Editors')],
      assignments: const {
        'ada': {'edit'},
        'grace': {'edit'},
        'linus': {'edit'},
      },
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
            rolesById: const {'ada': 'owner', 'grace': 'member'},
            lockedMemberIds: const {'ada'},
            onRoleChanged: onRoleChanged,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('GroupMembersView at compact widths', () {
    for (final width in [400.0, 360.0, 320.0, 280.0, 240.0]) {
      for (final withRoles in [true, false]) {
        testWidgets('lays out at ${width}px ${withRoles ? 'with' : 'without'} '
            'roles, selected or not', (tester) async {
          await pumpAt(
            tester,
            width,
            roles: withRoles ? _roles : const [],
            onRoleChanged: (_, _) {},
          );
          expect(tester.takeException(), isNull);

          await tester.tap(find.byType(Checkbox));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a narrow row moves its role under the name, aligned', (
      tester,
    ) async {
      await pumpAt(tester, 280, onRoleChanged: (_, _) {});

      for (final (name, role) in [
        ('Ada Lovelace', 'Billing administrator'),
        ('Grace Hopper', 'Member'),
        ('Linus Torvalds', 'Set role'),
      ]) {
        final title = tester.getTopLeft(_rowText(name));
        final roleAt = tester.getTopLeft(_rowText(role));
        expect(roleAt.dy, greaterThan(title.dy), reason: name);
        expect(roleAt.dx, title.dx, reason: name);
      }
      // Grace's role is still the editable menu.
      expect(find.widgetWithText(TextButton, 'Member'), findsOneWidget);
    });

    testWidgets('a wide row keeps its role beside Remove', (tester) async {
      await pumpAt(tester, 800, onRoleChanged: (_, _) {});

      expect(
        tester.getCenter(_rowText('Member')).dy,
        moreOrLessEquals(
          tester.getCenter(_rowText('Grace Hopper')).dy,
          epsilon: 1,
        ),
      );
    });
  });
}

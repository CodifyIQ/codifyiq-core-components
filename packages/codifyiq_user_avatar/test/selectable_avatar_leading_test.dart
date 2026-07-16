import 'dart:ui' show CheckedState;

import 'package:codifyiq_user_avatar/codifyiq_user_avatar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Material(child: child));

  testWidgets('shows the avatar (not the check icon) when unselected', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SelectableAvatarLeading(
          displayName: 'Ada Lovelace',
          selected: false,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('AL'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  testWidgets('shows a filled check icon when selected', (tester) async {
    await tester.pumpWidget(
      wrap(
        SelectableAvatarLeading(
          displayName: 'Ada Lovelace',
          selected: true,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('AL'), findsNothing);
  });

  testWidgets('hovering an unselected row reveals an outlined check icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SelectableAvatarLeading(
          displayName: 'Ada Lovelace',
          selected: false,
          onChanged: (_) {},
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byType(SelectableAvatarLeading)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('tapping toggles selection via onChanged', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => SelectableAvatarLeading(
            displayName: 'Ada Lovelace',
            selected: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SelectableAvatarLeading));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('exposes selected state and a name-aware label via semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        SelectableAvatarLeading(
          displayName: 'Ada Lovelace',
          selected: true,
          onChanged: (_) {},
        ),
      ),
    );

    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Deselect Ada Lovelace'),
    );
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
    handle.dispose();
  });

  testWidgets(
    "doesn't also expose UserAvatar's own semantics node when unselected",
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          SelectableAvatarLeading(
            displayName: 'Ada Lovelace',
            selected: false,
            onChanged: (_) {},
          ),
        ),
      );

      // The outer "Select ..." node is the only one a screen reader should
      // encounter — UserAvatar's own "Ada Lovelace" image-labeled node must
      // be excluded, or a screen reader announces both, redundantly, on
      // every row of every list this widget is used in.
      expect(find.bySemanticsLabel('Select Ada Lovelace'), findsOneWidget);
      expect(find.bySemanticsLabel('Ada Lovelace'), findsNothing);
      handle.dispose();
    },
  );
}

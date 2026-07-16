import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap({
    required int selectedCount,
    required bool allVisibleSelected,
    required ValueChanged<BulkSelectAll> onSelectAll,
    List<Widget> actions = const <Widget>[],
  }) => MaterialApp(
    home: Scaffold(
      body: BulkSelectionBar(
        selectedCount: selectedCount,
        allVisibleSelected: allVisibleSelected,
        onSelectAll: onSelectAll,
        actions: actions,
      ),
    ),
  );

  testWidgets('shows the empty label and an unchecked checkbox when nothing '
      'is selected', (tester) async {
    await tester.pumpWidget(
      wrap(selectedCount: 0, allVisibleSelected: false, onSelectAll: (_) {}),
    );

    expect(find.text('No items selected'), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
  });

  testWidgets('shows the running count and an indeterminate checkbox when '
      'some (but not all visible) are selected', (tester) async {
    await tester.pumpWidget(
      wrap(selectedCount: 2, allVisibleSelected: false, onSelectAll: (_) {}),
    );

    expect(find.text('2 selected'), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isNull);
  });

  testWidgets('shows a checked checkbox when every visible item is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(selectedCount: 3, allVisibleSelected: true, onSelectAll: (_) {}),
    );

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('tapping the checkbox selects all when not everything is '
      'already selected', (tester) async {
    BulkSelectAll? chosen;
    await tester.pumpWidget(
      wrap(
        selectedCount: 1,
        allVisibleSelected: false,
        onSelectAll: (value) => chosen = value,
      ),
    );

    await tester.tap(find.byType(Checkbox));
    expect(chosen, BulkSelectAll.all);
  });

  testWidgets('tapping the checkbox selects none once everything is already '
      'selected', (tester) async {
    BulkSelectAll? chosen;
    await tester.pumpWidget(
      wrap(
        selectedCount: 3,
        allVisibleSelected: true,
        onSelectAll: (value) => chosen = value,
      ),
    );

    await tester.tap(find.byType(Checkbox));
    expect(chosen, BulkSelectAll.none);
  });

  testWidgets('the dropdown offers explicit All / None choices', (
    tester,
  ) async {
    BulkSelectAll? chosen;
    await tester.pumpWidget(
      wrap(
        selectedCount: 1,
        allVisibleSelected: false,
        onSelectAll: (value) => chosen = value,
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    expect(chosen, BulkSelectAll.none);
  });

  testWidgets('actions are hidden but occupy their layout space until '
      'something is selected', (tester) async {
    const action = IconButton(
      onPressed: null,
      icon: Icon(Icons.group_add_outlined),
    );

    await tester.pumpWidget(
      wrap(
        selectedCount: 0,
        allVisibleSelected: false,
        onSelectAll: (_) {},
        actions: const [action],
      ),
    );
    // Measure the Visibility widget itself, not the whole bar — the bar's
    // overall width also shifts with the label text length ("No items
    // selected" vs. "1 selected"), which is unrelated to what this test is
    // checking.
    final hiddenSize = tester.getSize(find.byType(Visibility));
    // maintainState keeps the Icon mounted (that's the point — its space
    // stays reserved), so assert on Visibility.visible rather than the
    // Icon's mere presence in the tree.
    expect(tester.widget<Visibility>(find.byType(Visibility)).visible, false);

    await tester.pumpWidget(
      wrap(
        selectedCount: 1,
        allVisibleSelected: false,
        onSelectAll: (_) {},
        actions: const [action],
      ),
    );
    final visibleSize = tester.getSize(find.byType(Visibility));
    expect(tester.widget<Visibility>(find.byType(Visibility)).visible, true);

    // The actions' reserved space doesn't grow when they become visible —
    // it was already reserved while hidden.
    expect(visibleSize, hiddenSize);
  });

  testWidgets('leadingBoxSize resizes the checkbox box', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BulkSelectionBar(
            selectedCount: 0,
            allVisibleSelected: false,
            onSelectAll: (_) {},
            leadingBoxSize: 32,
          ),
        ),
      ),
    );

    final box = tester.widget<SizedBox>(
      find
          .ancestor(of: find.byType(Checkbox), matching: find.byType(SizedBox))
          .first,
    );
    expect(box.width, 32);
    expect(box.height, 32);
  });
}

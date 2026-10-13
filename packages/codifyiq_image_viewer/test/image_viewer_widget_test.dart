import 'dart:convert';

import 'package:codifyiq_image_viewer/codifyiq_image_viewer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';

// A 1x1 transparent PNG, so pages have a real image to decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

ImageViewerItem _item(String id) => ImageViewerItem(
  provider: MemoryImage(_png),
  id: id,
  filename: '$id.png',
  title: 'Image $id',
);

/// Hosts a viewer whose `items` can be swapped while it is open.
class _Host extends StatefulWidget {
  const _Host({
    required this.items,
    this.initialIndex = 0,
    this.onPageChanged,
    this.onDelete,
  });

  final List<ImageViewerItem> items;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
  final ImageViewerActionCallback? onDelete;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<ImageViewerItem> items = widget.items;

  void setItems(List<ImageViewerItem> next) => setState(() => items = next);

  // Changes the list the viewer was given, without replacing it.
  void mutateItems(void Function(List<ImageViewerItem> items) change) =>
      setState(() => change(items));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImageViewerWidget(
        items: items,
        initialIndex: widget.initialIndex,
        onPageChanged: widget.onPageChanged,
        onDelete: widget.onDelete,
      ),
    );
  }
}

// The loading spinner animates forever, so settle with fixed pumps instead
// of pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _setItems(WidgetTester tester, List<ImageViewerItem> items) async {
  tester.state<_HostState>(find.byType(_Host)).setItems(items);
  await _settle(tester);
}

Future<void> _mutateItems(
  WidgetTester tester,
  void Function(List<ImageViewerItem> items) change,
) async {
  tester.state<_HostState>(find.byType(_Host)).mutateItems(change);
  await _settle(tester);
}

Future<void> _chooseFromOverflow(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await _settle(tester);
  await tester.tap(find.text(label));
  await _settle(tester);
}

void main() {
  group('paging', () {
    testWidgets('opens on initialIndex and shows the page indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Host(items: [_item('a'), _item('b'), _item('c')], initialIndex: 1),
      );
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('clamps an out-of-range initialIndex', (tester) async {
      await tester.pumpWidget(
        _Host(items: [_item('a'), _item('b')], initialIndex: 9),
      );
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('arrow keys move between pages and report the change', (
      tester,
    ) async {
      final changes = <int>[];
      await tester.pumpWidget(
        _Host(
          items: [_item('a'), _item('b'), _item('c')],
          onPageChanged: changes.add,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _settle(tester);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(changes, [1, 0]);
    });
  });

  group('changing items while open', () {
    testWidgets('removing the last image while viewing it shows the new last', (
      tester,
    ) async {
      final changes = <int>[];
      final a = _item('a'), b = _item('b'), c = _item('c');
      await tester.pumpWidget(
        _Host(items: [a, b, c], initialIndex: 2, onPageChanged: changes.add),
      );
      await _setItems(tester, [a, b]);

      expect(tester.takeException(), isNull);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(changes, [1]);
    });

    testWidgets('removing the viewed middle image shows its successor', (
      tester,
    ) async {
      final changes = <int>[];
      final a = _item('a'), b = _item('b'), c = _item('c');
      await tester.pumpWidget(
        _Host(items: [a, b, c], initialIndex: 1, onPageChanged: changes.add),
      );
      await _setItems(tester, [a, c]);

      expect(tester.takeException(), isNull);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(changes, isEmpty);
    });

    testWidgets('removing an earlier image stays on the viewed image', (
      tester,
    ) async {
      final changes = <int>[];
      await tester.pumpWidget(
        _Host(
          items: [_item('a'), _item('b'), _item('c')],
          initialIndex: 2,
          onPageChanged: changes.add,
        ),
      );
      // Fresh instances: the viewed image is recognised by its id.
      await _setItems(tester, [_item('b'), _item('c')]);

      expect(tester.takeException(), isNull);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(changes, [1]);

      // Paging still works from the repositioned page.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _settle(tester);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('removing down to a single image does not throw', (
      tester,
    ) async {
      final a = _item('a'), b = _item('b'), c = _item('c');
      await tester.pumpWidget(_Host(items: [a, b, c], initialIndex: 2));
      await _setItems(tester, [a]);

      expect(tester.takeException(), isNull);
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('adding images keeps the viewed image and allows paging on', (
      tester,
    ) async {
      final a = _item('a'), b = _item('b');
      await tester.pumpWidget(_Host(items: [a, b], initialIndex: 1));
      await _setItems(tester, [a, b, _item('c')]);

      expect(tester.takeException(), isNull);
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('removing the viewed image from the same list in place', (
      tester,
    ) async {
      final changes = <int>[];
      final deleted = <String>[];
      await tester.pumpWidget(
        _Host(
          items: [_item('a'), _item('b'), _item('c')],
          initialIndex: 2,
          onPageChanged: changes.add,
          onDelete: (item, index) => deleted.add('${item.id} $index'),
        ),
      );
      // The consumer keeps one list and removes from it, so the viewer is
      // handed the very same list instance again.
      await _mutateItems(tester, (items) => items.removeLast());

      expect(tester.takeException(), isNull);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(changes, [1]);

      await _chooseFromOverflow(tester, 'Delete');
      expect(tester.takeException(), isNull);
      expect(deleted, ['b 1']);
    });

    testWidgets('removing in place and then passing a copy', (tester) async {
      final items = [_item('a'), _item('b'), _item('c')];
      await tester.pumpWidget(_Host(items: items, initialIndex: 2));
      items.removeLast();
      await _setItems(tester, [...items]);

      expect(tester.takeException(), isNull);
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('adding earlier images stays on the viewed image', (
      tester,
    ) async {
      final changes = <int>[];
      final deleted = <String>[];
      final a = _item('a'), b = _item('b');
      await tester.pumpWidget(
        _Host(
          items: [a, b],
          onPageChanged: changes.add,
          onDelete: (item, index) => deleted.add('${item.id} $index'),
        ),
      );
      await _setItems(tester, [_item('x'), a, b]);

      expect(tester.takeException(), isNull);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(changes, [1]);

      await _chooseFromOverflow(tester, 'Delete');
      expect(deleted, ['a 1']);
    });

    testWidgets('a zoomed image does not pass its zoom to a neighbour', (
      tester,
    ) async {
      final a = _item('a'), b = _item('b'), c = _item('c');
      await tester.pumpWidget(_Host(items: [a, b, c], initialIndex: 1));

      // Zoom in on b, then remove a so every image moves up a page.
      final onB = tester.widgetList<PhotoView>(find.byType(PhotoView)).last;
      onB.scaleStateController!.scaleState = PhotoViewScaleState.zoomedIn;
      await _settle(tester);
      await _setItems(tester, [b, c]);

      expect(tester.takeException(), isNull);
      expect(find.text('1 / 2'), findsOneWidget);
      for (final page in tester.widgetList<PhotoView>(find.byType(PhotoView))) {
        expect(
          page.scaleStateController!.scaleState,
          PhotoViewScaleState.initial,
        );
      }

      // No zoom left over to block paging on to c.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('rebuilding with duplicate images does not move the page', (
      tester,
    ) async {
      // No ids, and every item loads from an equal source.
      List<ImageViewerItem> build() => [
        for (var i = 0; i < 4; i++)
          ImageViewerItem(provider: MemoryImage(_png)),
      ];
      final changes = <int>[];
      await tester.pumpWidget(
        _Host(items: build(), initialIndex: 3, onPageChanged: changes.add),
      );
      await _setItems(tester, build());

      expect(find.text('4 / 4'), findsOneWidget);
      expect(changes, isEmpty);
    });

    testWidgets('rebuilding with equal items changes nothing', (tester) async {
      final changes = <int>[];
      await tester.pumpWidget(
        _Host(
          items: [_item('a'), _item('b')],
          initialIndex: 1,
          onPageChanged: changes.add,
        ),
      );
      await _setItems(tester, [_item('a'), _item('b')]);

      expect(find.text('2 / 2'), findsOneWidget);
      expect(changes, isEmpty);
    });
  });

  group('actions', () {
    Future<void> pumpViewer(
      WidgetTester tester, {
      ImageViewerShareCallback? onShare,
      ImageViewerActionCallback? onDownload,
      ImageViewerActionCallback? onDelete,
      List<ImageViewerAction> actions = const [],
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: ImageViewerWidget(
            items: [_item('a'), _item('b')],
            initialIndex: 1,
            onShare: onShare,
            onDownload: onDownload,
            onDelete: onDelete,
            actions: actions,
          ),
        ),
      );
    }

    testWidgets('hides the overflow menu when there is nothing to put in it', (
      tester,
    ) async {
      await pumpViewer(tester, onShare: (_, _, _) {});
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('share reports the visible item, index and button rect', (
      tester,
    ) async {
      ImageViewerItem? shared;
      int? sharedIndex;
      Rect? origin;
      await pumpViewer(
        tester,
        onShare: (item, index, rect) {
          shared = item;
          sharedIndex = index;
          origin = rect;
        },
      );
      await tester.tap(find.byIcon(Icons.share_outlined));

      expect(shared?.id, 'b');
      expect(shared?.filename, 'b.png');
      expect(sharedIndex, 1);
      expect(origin, isNotNull);
    });

    testWidgets('download and delete report the visible item', (tester) async {
      final calls = <String>[];
      await pumpViewer(
        tester,
        onDownload: (item, index) => calls.add('download ${item.id} $index'),
        onDelete: (item, index) => calls.add('delete ${item.id} $index'),
      );
      await _chooseFromOverflow(tester, 'Download');
      await _chooseFromOverflow(tester, 'Delete');

      expect(calls, ['download b 1', 'delete b 1']);
    });

    testWidgets(
      'a custom action appears in the overflow and reports the item',
      (tester) async {
        final calls = <String>[];
        await pumpViewer(
          tester,
          actions: [
            ImageViewerAction(
              label: 'Set as featured',
              icon: Icons.star_outline,
              onSelected: (item, index) => calls.add('${item.id} $index'),
            ),
          ],
        );
        await _chooseFromOverflow(tester, 'Set as featured');

        expect(calls, ['b 1']);
      },
    );
  });
}

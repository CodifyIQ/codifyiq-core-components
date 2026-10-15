import 'dart:convert';

import 'package:codifyiq_image_viewer/codifyiq_image_viewer.dart';
import 'package:codifyiq_image_viewer/src/page_dots.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

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

// Under the test clock, Chrome never finishes decoding the test image, so a
// page stays on its loading spinner and taps never reach the image.
const _tapSkip = kIsWeb;

// These expect the mobile buttons; on web, Share and Download swap places.
const _mobileLayoutSkip = kIsWeb;

// The page dots in the footer.
final _dots = find.descendant(
  of: find.byType(PageDots),
  matching: find.byType(AnimatedContainer),
);

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
    }, skip: _mobileLayoutSkip);

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
    }, skip: _mobileLayoutSkip);

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
    }, skip: _mobileLayoutSkip);

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

  group('header and footer', () {
    Future<void> pumpViewer(
      WidgetTester tester, {
      required List<ImageViewerItem> items,
      int initialIndex = 0,
      List<ImageViewerAction> actions = const [],
      ImageViewerTitleBuilder? titleBuilder,
      ImageViewerFooterBuilder? footerBuilder,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageViewerWidget(
            items: items,
            initialIndex: initialIndex,
            actions: actions,
            titleBuilder: titleBuilder,
            footerBuilder: footerBuilder,
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('the header shows the title above the page indicator', (
      tester,
    ) async {
      await pumpViewer(tester, items: [_item('a'), _item('b')]);

      expect(find.text('Image a'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('the header falls back to the filename, then the indicator', (
      tester,
    ) async {
      await pumpViewer(
        tester,
        items: [
          ImageViewerItem(provider: MemoryImage(_png), filename: 'a.png'),
          ImageViewerItem(provider: MemoryImage(_png)),
        ],
      );
      expect(find.text('a.png'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.text('a.png'), findsNothing);
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('titleBuilder replaces the title', (tester) async {
      await pumpViewer(
        tester,
        items: [_item('a'), _item('b')],
        initialIndex: 1,
        titleBuilder: (context, item, index, total) =>
            Text('${item.id} of $total'),
      );

      expect(find.text('b of 2'), findsOneWidget);
      expect(find.text('Image b'), findsNothing);
    });

    testWidgets('the footer shows the caption and page dots', (tester) async {
      await pumpViewer(
        tester,
        items: [
          ImageViewerItem(provider: MemoryImage(_png), caption: 'Kitchen'),
          _item('b'),
          _item('c'),
        ],
      );

      expect(find.text('Kitchen'), findsOneWidget);
      expect(_dots, findsNWidgets(3));
    });

    testWidgets('a single image without a caption has no footer', (
      tester,
    ) async {
      await pumpViewer(tester, items: [_item('a')]);

      expect(_dots, findsNothing);
    });

    testWidgets('more than 20 images get no dots', (tester) async {
      await pumpViewer(
        tester,
        items: [for (var i = 0; i < 21; i++) _item('$i')],
      );

      expect(_dots, findsNothing);
    });

    testWidgets('footerBuilder replaces the footer, or removes it', (
      tester,
    ) async {
      final captioned = ImageViewerItem(
        provider: MemoryImage(_png),
        caption: 'Kitchen',
      );
      await pumpViewer(
        tester,
        items: [captioned, _item('b')],
        footerBuilder: (context, item, index, total) => Text('page $index'),
      );
      expect(find.text('page 0'), findsOneWidget);
      expect(find.text('Kitchen'), findsNothing);

      await pumpViewer(
        tester,
        items: [captioned, _item('b')],
        footerBuilder: (context, item, index, total) => null,
      );
      expect(find.text('Kitchen'), findsNothing);
      expect(_dots, findsNothing);
    });

    testWidgets('header actions show per image and report the item', (
      tester,
    ) async {
      final calls = <String>[];
      await pumpViewer(
        tester,
        items: [_item('a'), _item('b')],
        actions: [
          ImageViewerAction(
            label: 'Set as featured',
            icon: Icons.star_outline,
            showInAppBar: true,
            // 'a' is already featured.
            isVisible: (item, index) => item.id != 'a',
            onSelected: (item, index) => calls.add('${item.id} $index'),
          ),
        ],
      );
      expect(find.byTooltip('Set as featured'), findsNothing);
      // Nothing left for the overflow menu.
      expect(find.byIcon(Icons.more_vert), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      await tester.tap(find.byTooltip('Set as featured'));

      expect(calls, ['b 1']);
    });
  });

  group('layout', () {
    // Sizes the test window in logical pixels.
    void setWindowSize(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Widget viewer({
      List<ImageViewerItem>? items,
      ImageViewerControlsLayout? controlsLayout,
      EdgeInsetsGeometry? contentPadding,
      bool controlsHideOnTap = true,
    }) => ImageViewerWidget(
      items: items ?? [_item('a'), _item('b')],
      controlsLayout: controlsLayout,
      contentPadding: contentPadding,
      controlsHideOnTap: controlsHideOnTap,
    );

    Future<void> pumpViewer(
      WidgetTester tester, {
      List<ImageViewerItem>? items,
      ImageViewerControlsLayout? controlsLayout,
      EdgeInsetsGeometry? contentPadding,
      bool controlsHideOnTap = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: viewer(
            items: items,
            controlsLayout: controlsLayout,
            contentPadding: contentPadding,
            controlsHideOnTap: controlsHideOnTap,
          ),
        ),
      );
      await _settle(tester);
    }

    Rect galleryRect(WidgetTester tester) =>
        tester.getRect(find.byType(PhotoViewGallery));

    // The area photo_view fits the image into, when padding is even.
    Size? fitArea(WidgetTester tester) => tester
        .widget<PhotoViewGallery>(find.byType(PhotoViewGallery))
        .customSize;

    Finder fadingHeader() => find.ancestor(
      of: find.byType(AppBar),
      matching: find.byType(AnimatedOpacity),
    );

    double headerOpacity(WidgetTester tester) =>
        tester.widget<AnimatedOpacity>(fadingHeader()).opacity;

    Future<void> tapImage(WidgetTester tester) async {
      await tester.tapAt(galleryRect(tester).center);
      // Wait out the double-tap-to-zoom window.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('wide windows fit the image between header and footer', (
      tester,
    ) async {
      setWindowSize(tester, const Size(1024, 768));
      await pumpViewer(tester);

      final header = tester.getRect(find.byType(AppBar));
      final gallery = galleryRect(tester);
      // The gallery, and its gestures, reach the margin; the image fits
      // inside it.
      expect(gallery.top, header.bottom);
      expect(gallery.left, 0);
      expect(fitArea(tester), gallery.size - const Offset(48, 48) as Size);
      // The header always shows.
      expect(fadingHeader(), findsNothing);
    });

    testWidgets('compact windows show the image full screen under the header', (
      tester,
    ) async {
      setWindowSize(tester, const Size(400, 800));
      await pumpViewer(tester);

      expect(galleryRect(tester), const Rect.fromLTRB(0, 0, 400, 800));
      expect(fitArea(tester), Size(kIsWeb ? 400 : 376, 800));
      expect(fadingHeader(), findsOneWidget);
    });

    testWidgets('a phone in landscape gets the overlay layout', (tester) async {
      setWindowSize(tester, const Size(844, 390));
      await pumpViewer(tester);

      expect(galleryRect(tester).top, 0);
      expect(fadingHeader(), findsOneWidget);
    });

    testWidgets('rotating keeps the page being viewed', (tester) async {
      setWindowSize(tester, const Size(1024, 768));
      await pumpViewer(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.text('2 / 2'), findsOneWidget);

      setWindowSize(tester, const Size(400, 800));
      await _settle(tester);

      expect(fadingHeader(), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
    });

    testWidgets('in compact windows, tapping the image hides the controls', (
      tester,
    ) async {
      setWindowSize(tester, const Size(400, 800));
      await pumpViewer(tester);
      expect(headerOpacity(tester), 1);

      await tapImage(tester);
      expect(headerOpacity(tester), 0);

      await tapImage(tester);
      expect(headerOpacity(tester), 1);
    }, skip: _tapSkip);

    testWidgets('tapping an image that failed to load toggles the controls', (
      tester,
    ) async {
      setWindowSize(tester, const Size(400, 800));
      await pumpViewer(
        tester,
        items: [ImageViewerItem(provider: MemoryImage(Uint8List(8)))],
      );
      expect(find.text('Unable to load image'), findsOneWidget);

      await tester.tap(find.text('Unable to load image'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(headerOpacity(tester), 0);
    }, skip: _tapSkip);

    testWidgets('controlsHideOnTap false keeps the controls', (tester) async {
      setWindowSize(tester, const Size(400, 800));
      await pumpViewer(tester, controlsHideOnTap: false);

      await tapImage(tester);
      expect(headerOpacity(tester), 1);
    }, skip: _tapSkip);

    testWidgets('controlsLayout and contentPadding override the defaults', (
      tester,
    ) async {
      setWindowSize(tester, const Size(1024, 768));
      await pumpViewer(
        tester,
        controlsLayout: ImageViewerControlsLayout.overlay,
        contentPadding: const EdgeInsets.all(40),
      );

      expect(galleryRect(tester), const Rect.fromLTRB(0, 0, 1024, 768));
      expect(fitArea(tester), const Size(944, 688));
      expect(headerOpacity(tester), 1);
    });

    testWidgets('uneven contentPadding pads the gallery itself', (
      tester,
    ) async {
      setWindowSize(tester, const Size(1024, 768));
      await pumpViewer(
        tester,
        controlsLayout: ImageViewerControlsLayout.overlay,
        contentPadding: const EdgeInsets.fromLTRB(10, 20, 30, 40),
      );

      expect(galleryRect(tester), const Rect.fromLTRB(10, 20, 994, 728));
      expect(fitArea(tester), isNull);
    });

    testWidgets('pull-to-dismiss works from the margin', (tester) async {
      setWindowSize(tester, const Size(1024, 768));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => viewer())),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);

      // Down from the left margin, beside the image.
      final start = Offset(10, galleryRect(tester).center.dy);
      await tester.dragFrom(start, const Offset(0, 300));
      // The drag animates away, then the route closes.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ImageViewerWidget), findsNothing);
    }, skip: kIsWeb);

    testWidgets('Escape closes the viewer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => viewer())),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ImageViewerWidget), findsNothing);
    });
  });

  testWidgets('shows the close button only when there is a route to close', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ImageViewerWidget(items: [_item('a')])),
    );
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ImageViewerWidget(items: [_item('a')]),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(ImageViewerWidget), findsNothing);
  });
}

import 'dart:async';
import 'dart:ui' as ui;

import 'package:codifyiq_image_viewer/codifyiq_image_viewer.dart';
import 'package:codifyiq_image_viewer/src/placeholder_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// An image that loads when the test says so, or fails.
class _ControlledImage extends ImageProvider<_ControlledImage> {
  _ControlledImage(this.name);

  final String name;
  final Completer<ImageInfo> _info = Completer<ImageInfo>();

  void load(ui.Image image) => _info.complete(ImageInfo(image: image));

  void fail() => _info.completeError(StateError('$name failed'));

  @override
  Future<_ControlledImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _ControlledImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_info.future);
}

/// An image that is already loaded, like a thumbnail in the image cache.
class _LoadedImage extends ImageProvider<_LoadedImage> {
  _LoadedImage(this.image);

  final ui.Image image;

  @override
  Future<_LoadedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _LoadedImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    SynchronousFuture(ImageInfo(image: image.clone())),
  );
}

Future<ui.Image> _image(WidgetTester tester, int size) async =>
    (await tester.runAsync(() => createTestImage(width: size, height: size)))!;

Future<void> _pumpViewer(WidgetTester tester, ImageViewerItem item) async {
  await tester.pumpWidget(MaterialApp(home: ImageViewerWidget(items: [item])));
  await tester.pump();
}

/// The width of the image the visible page is drawing, or null.
int? _shownWidth(WidgetTester tester) {
  final raw = find.byType(RawImage);
  if (raw.evaluate().isEmpty) return null;
  return tester.widget<RawImage>(raw.first).image?.width;
}

void main() {
  testWidgets('shows the placeholder instead of a spinner, then the image', (
    tester,
  ) async {
    final full = _ControlledImage('full');
    final placeholder = _ControlledImage('placeholder');
    await _pumpViewer(
      tester,
      ImageViewerItem(provider: full, placeholder: placeholder),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    placeholder.load(await _image(tester, 4));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_shownWidth(tester), 4);

    full.load(await _image(tester, 16));
    await tester.pump();
    await tester.pump();
    expect(_shownWidth(tester), 16);
  });

  testWidgets(
    'swaps in the image after a placeholder that was already loaded',
    (tester) async {
      final full = _ControlledImage('full');
      final placeholder = _LoadedImage(await _image(tester, 4));
      await _pumpViewer(
        tester,
        ImageViewerItem(provider: full, placeholder: placeholder),
      );
      expect(_shownWidth(tester), 4);

      full.load(await _image(tester, 16));
      await tester.pump();
      await tester.pump();
      expect(_shownWidth(tester), 16);
    },
  );

  testWidgets('keeps the full image when the placeholder arrives late', (
    tester,
  ) async {
    final full = _ControlledImage('full');
    final placeholder = _ControlledImage('placeholder');
    await _pumpViewer(
      tester,
      ImageViewerItem(provider: full, placeholder: placeholder),
    );

    full.load(await _image(tester, 16));
    await tester.pump();
    placeholder.load(await _image(tester, 4));
    await tester.pump();
    await tester.pump();

    expect(_shownWidth(tester), 16);
  });

  testWidgets('ignores a placeholder that fails to load', (tester) async {
    final full = _ControlledImage('full');
    final placeholder = _ControlledImage('placeholder');
    await _pumpViewer(
      tester,
      ImageViewerItem(provider: full, placeholder: placeholder),
    );

    placeholder.fail();
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);

    full.load(await _image(tester, 16));
    await tester.pump();
    await tester.pump();
    expect(_shownWidth(tester), 16);
  });

  testWidgets('shows the error when the full image fails', (tester) async {
    final full = _ControlledImage('full');
    final placeholder = _ControlledImage('placeholder');
    await _pumpViewer(
      tester,
      ImageViewerItem(provider: full, placeholder: placeholder),
    );

    placeholder.load(await _image(tester, 4));
    await tester.pump();
    full.fail();
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  test('the network constructor passes the placeholder through', () {
    const thumbnail = NetworkImage('https://example.com/a-thumb.jpg');
    final item = ImageViewerItem.network(
      'https://example.com/a.jpg',
      placeholder: thumbnail,
    );
    expect(item.placeholder, same(thumbnail));
  });

  test('placeholder images are equal by their images', () {
    const full = NetworkImage('https://example.com/a.jpg');
    const thumbnail = NetworkImage('https://example.com/a-thumb.jpg');
    expect(
      const PlaceholderImage(full, thumbnail),
      const PlaceholderImage(full, thumbnail),
    );
    expect(
      const PlaceholderImage(full, thumbnail).hashCode,
      const PlaceholderImage(full, thumbnail).hashCode,
    );
  });
}

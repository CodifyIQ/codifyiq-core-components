import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// An image embedded in a `data:` URI, such as a small inline thumbnail.
///
/// Unlike a [MemoryImage] made from the decoded bytes, it is keyed by the URI,
/// so rebuilding a bubble finds the image already in the cache.
class DataUriImage extends ImageProvider<DataUriImage> {
  /// Creates a [DataUriImage] from [uri].
  const DataUriImage(this.uri);

  /// The `data:` URI holding the encoded image.
  final String uri;

  @override
  Future<DataUriImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    DataUriImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _decode(decode), scale: 1);

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async => decode(
    await ui.ImmutableBuffer.fromUint8List(UriData.parse(uri).contentAsBytes()),
  );

  @override
  bool operator ==(Object other) => other is DataUriImage && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'DataUriImage(${uri.length} characters)';
}

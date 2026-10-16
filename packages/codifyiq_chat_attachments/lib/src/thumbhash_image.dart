import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:thumbhash/thumbhash.dart' as thumbhash;

/// A blurred placeholder decoded from a message's ThumbHash.
///
/// Keyed by the hash, so rebuilding a bubble finds it already in the cache.
class ThumbhashImage extends ImageProvider<ThumbhashImage> {
  /// Creates a [ThumbhashImage] from a base64 [hash].
  const ThumbhashImage(this.hash);

  /// The base64-encoded ThumbHash.
  final String hash;

  /// The image's approximate width divided by its height, or `null` when
  /// [hash] can't be decoded.
  double? get aspectRatio {
    if (_aspectRatios.containsKey(hash)) return _aspectRatios[hash];
    if (_aspectRatios.length >= 256) {
      _aspectRatios.remove(_aspectRatios.keys.first);
    }
    try {
      return _aspectRatios[hash] = thumbhash.thumbHashToApproximateAspectRatio(
        _bytes,
      );
    } on Object {
      return _aspectRatios[hash] = null;
    }
  }

  // Each hash's aspect ratio, so a rebuilt bubble doesn't decode it again.
  static final _aspectRatios = <String, double?>{};

  Uint8List get _bytes => base64.decode(base64.normalize(hash));

  @override
  Future<ThumbhashImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    ThumbhashImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _decode(decode), scale: 1);

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async => decode(
    await ui.ImmutableBuffer.fromUint8List(
      thumbhash.rgbaToBmp(thumbhash.thumbHashToRGBA(_bytes)),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is ThumbhashImage && other.hash == hash;

  @override
  int get hashCode => hash.hashCode;

  @override
  String toString() => 'ThumbhashImage($hash)';
}

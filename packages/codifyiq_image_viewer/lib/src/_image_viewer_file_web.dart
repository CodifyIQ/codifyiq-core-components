import 'package:flutter/widgets.dart';

/// Web stub for [fileImageProvider].
///
/// Flutter web has no `dart:io` [File], so this throws when invoked. Callers
/// should use [ImageViewerItem.network] or [ImageViewerItem.asset] on the web
/// target instead.
ImageProvider fileImageProvider(String path) {
  throw UnsupportedError(
    'ImageViewerItem.file is not supported on Flutter web. '
    'Use ImageViewerItem.network or ImageViewerItem.asset, or pass a custom '
    'ImageProvider via the default ImageViewerItem constructor.',
  );
}

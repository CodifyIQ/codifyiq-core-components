import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// An [ImageProvider] that shows [placeholder] until [image] has loaded, then
/// [image].
///
/// It emits each as a frame of one stream, so `photo_view` shows the
/// placeholder in place of its loading indicator and swaps to the full image
/// without rebuilding the page. A placeholder that fails to load is ignored.
@immutable
class PlaceholderImage extends ImageProvider<PlaceholderImage> {
  /// Creates a [PlaceholderImage].
  const PlaceholderImage(this.image, this.placeholder);

  /// The full image.
  final ImageProvider image;

  /// The low-resolution image shown until [image] has loaded.
  final ImageProvider placeholder;

  @override
  Future<PlaceholderImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    PlaceholderImage key,
    ImageDecoderCallback decode,
  ) => _PlaceholderCompleter(
    placeholder.resolve(ImageConfiguration.empty),
    image.resolve(ImageConfiguration.empty),
  );

  @override
  bool operator ==(Object other) =>
      other is PlaceholderImage &&
      other.image == image &&
      other.placeholder == placeholder;

  @override
  int get hashCode => Object.hash(image, placeholder);
}

class _PlaceholderCompleter extends ImageStreamCompleter {
  _PlaceholderCompleter(this._placeholderStream, this._imageStream) {
    _placeholderListener = ImageStreamListener(
      (info, _) => setImage(info),
      onError: (_, _) =>
          _placeholderStream.removeListener(_placeholderListener),
    );
    _imageListener = ImageStreamListener(
      (info, _) {
        _hasFullImage = true;
        _placeholderStream.removeListener(_placeholderListener);
        setImage(info);
      },
      onChunk: reportImageChunkEvent,
      onError: (exception, stack) => reportError(
        context: ErrorDescription('while loading the full image'),
        exception: exception,
        stack: stack,
      ),
    );
    _listen();
    // The image cache takes the first frame and stops listening, which can
    // leave no listeners for a moment when the placeholder is already loaded.
    // Stop loading then, and start again when a listener comes back.
    addOnLastListenerRemovedCallback(_stop);
  }

  final ImageStream _placeholderStream;
  final ImageStream _imageStream;
  late final ImageStreamListener _placeholderListener;
  late final ImageStreamListener _imageListener;
  bool _hasFullImage = false;
  bool _isListening = false;

  @override
  void addListener(ImageStreamListener listener) {
    super.addListener(listener);
    _listen();
  }

  void _listen() {
    if (_isListening) return;
    _isListening = true;
    // The full image first, so one already in the cache wins outright.
    _imageStream.addListener(_imageListener);
    if (!_hasFullImage) _placeholderStream.addListener(_placeholderListener);
  }

  void _stop() {
    _isListening = false;
    _imageStream.removeListener(_imageListener);
    _placeholderStream.removeListener(_placeholderListener);
  }
}

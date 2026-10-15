import 'package:flutter/foundation.dart';

/// The source from which a video is loaded.
///
/// Construct one of the concrete variants and hand it to a
/// `VideoViewerWidget` or `VideoViewerScreen`:
///
/// ```dart
/// VideoViewerWidget(source: VideoSource.uri(Uri.parse('https://example.com/clip.mp4')))
/// VideoViewerWidget(source: VideoSource.file('/path/to/clip.mp4'))
/// VideoViewerWidget(source: VideoSource.asset('assets/clip.mp4'))
/// ```
sealed class VideoSource {
  const VideoSource();

  /// Loads a video from a network [Uri].
  ///
  /// [headers] are sent with the HTTP request — supply authentication or
  /// authorization headers here (e.g. a JWT bearer token) for endpoints that
  /// require them. Browsers don't allow headers on video requests, so they are
  /// ignored on web; use a signed or cookie-authenticated URL there.
  ///
  /// The server should support HTTP range requests so the player can seek
  /// and start playback without downloading the whole file.
  const factory VideoSource.uri(Uri uri, {Map<String, String>? headers}) =
      VideoUriSource;

  /// Loads a video from a local file path. Not supported on web.
  const factory VideoSource.file(String path) = VideoFileSource;

  /// Loads a video from the app's asset bundle.
  ///
  /// [package] is the name of the package that owns the asset, when it isn't
  /// the app itself.
  const factory VideoSource.asset(String name, {String? package}) =
      VideoAssetSource;
}

/// A [VideoSource] backed by a network [Uri].
final class VideoUriSource extends VideoSource {
  /// Creates a [VideoUriSource] that loads from [uri], sending [headers] with
  /// the request. See [VideoSource.uri].
  const VideoUriSource(this.uri, {this.headers});

  /// The URI to load the video from.
  final Uri uri;

  /// Optional HTTP headers sent with the request, e.g. for authentication.
  /// Ignored on web.
  final Map<String, String>? headers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoUriSource &&
          other.uri == uri &&
          mapEquals(other.headers, headers));

  @override
  int get hashCode => Object.hash(
    uri,
    headers == null
        ? null
        : Object.hashAllUnordered(
            headers!.entries.map((e) => Object.hash(e.key, e.value)),
          ),
  );
}

/// A [VideoSource] backed by a local file path.
final class VideoFileSource extends VideoSource {
  /// Creates a [VideoFileSource] that reads from [path].
  const VideoFileSource(this.path);

  /// The absolute or relative file path of the video.
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoFileSource && other.path == path);

  @override
  int get hashCode => path.hashCode;
}

/// A [VideoSource] backed by a bundled asset.
final class VideoAssetSource extends VideoSource {
  /// Creates a [VideoAssetSource] for the asset called [name].
  const VideoAssetSource(this.name, {this.package});

  /// The asset's name, as declared in `pubspec.yaml`.
  final String name;

  /// The package that owns the asset, or `null` for the app itself.
  final String? package;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoAssetSource &&
          other.name == name &&
          other.package == package);

  @override
  int get hashCode => Object.hash(name, package);
}

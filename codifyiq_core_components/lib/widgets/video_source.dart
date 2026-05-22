/// The source from which a video is loaded.
///
/// Construct one of the concrete variants and hand it to a
/// [VideoMessageWidget]:
///
/// ```dart
/// VideoMessageWidget(source: VideoSource.network(Uri.parse('https://example.com/clip.mp4')))
/// VideoMessageWidget(source: VideoSource.asset('assets/videos/demo.mp4'))
/// VideoMessageWidget(source: VideoSource.file('/path/to/video.mp4'))
/// ```
sealed class VideoSource {
  const VideoSource();

  /// Loads a video from a network [Uri].
  ///
  /// [headers] are forwarded as HTTP headers on the video request — use this
  /// for endpoints that require authentication (e.g. a JWT bearer token).
  ///
  /// On web, the server must serve appropriate CORS headers.
  const factory VideoSource.network(Uri uri, {Map<String, String>? headers}) =
      VideoNetworkSource;

  /// Loads a video from a Flutter asset path (e.g. `'assets/videos/demo.mp4'`).
  ///
  /// The path must be declared under `flutter: assets:` in `pubspec.yaml`.
  const factory VideoSource.asset(String path) = VideoAssetSource;

  /// Loads a video from a local file path. Not supported on web.
  const factory VideoSource.file(String path) = VideoFileSource;
}

/// A [VideoSource] backed by a network [Uri].
final class VideoNetworkSource extends VideoSource {
  /// Creates a [VideoNetworkSource] that loads from [uri].
  const VideoNetworkSource(this.uri, {this.headers});

  /// The URI to fetch the video from.
  final Uri uri;

  /// Optional HTTP headers sent with the video request.
  final Map<String, String>? headers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoNetworkSource && other.uri == uri);

  @override
  int get hashCode => uri.hashCode;
}

/// A [VideoSource] backed by a Flutter asset path.
final class VideoAssetSource extends VideoSource {
  /// Creates a [VideoAssetSource] that reads from [path].
  const VideoAssetSource(this.path);

  /// The asset path declared in `pubspec.yaml` (e.g. `'assets/videos/demo.mp4'`).
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoAssetSource && other.path == path);

  @override
  int get hashCode => path.hashCode;
}

/// A [VideoSource] backed by a local file path. Not supported on web.
final class VideoFileSource extends VideoSource {
  /// Creates a [VideoFileSource] that reads from [path].
  const VideoFileSource(this.path);

  /// The absolute file path of the video.
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoFileSource && other.path == path);

  @override
  int get hashCode => path.hashCode;
}

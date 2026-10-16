/// The source from which an audio message is loaded.
///
/// Construct one of the concrete variants and hand it to an
/// `AudioMessageWidget`:
///
/// ```dart
/// AudioMessageWidget(source: AudioMessageSource.uri(Uri.parse('https://example.com/note.m4a')))
/// AudioMessageWidget(source: AudioMessageSource.file('/path/to/note.m4a'))
/// AudioMessageWidget(source: AudioMessageSource.asset('assets/note.m4a'))
/// ```
sealed class AudioMessageSource {
  /// Base constructor for the concrete sources; use the factories instead.
  const AudioMessageSource();

  /// Loads audio from a network [Uri].
  ///
  /// [headers] are sent with the HTTP request — supply authentication or
  /// authorization headers here for endpoints that require them. Browsers
  /// don't allow headers on audio requests, so they are ignored on web; use a
  /// signed or cookie-authenticated URL there.
  const factory AudioMessageSource.uri(
    Uri uri, {
    Map<String, String>? headers,
  }) = AudioMessageUriSource;

  /// Loads audio from a local file path. Not supported on web.
  const factory AudioMessageSource.file(String path) = AudioMessageFileSource;

  /// Loads audio from the app's asset bundle.
  ///
  /// [package] is the name of the package that owns the asset, when it isn't
  /// the app itself.
  const factory AudioMessageSource.asset(String name, {String? package}) =
      AudioMessageAssetSource;
}

/// An [AudioMessageSource] backed by a network [Uri].
final class AudioMessageUriSource extends AudioMessageSource {
  /// Creates an [AudioMessageUriSource] that loads from [uri], sending
  /// [headers] with the request. See [AudioMessageSource.uri].
  const AudioMessageUriSource(this.uri, {this.headers});

  /// The URI to load the audio from.
  final Uri uri;

  /// Optional HTTP headers sent with the request, e.g. for authentication.
  /// Ignored on web.
  ///
  /// Not part of the source's identity: a source with new headers, such as a
  /// refreshed token, is the same message and keeps playing.
  final Map<String, String>? headers;

  @override
  bool operator ==(Object other) =>
      other is AudioMessageUriSource && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

/// An [AudioMessageSource] backed by a local file path.
final class AudioMessageFileSource extends AudioMessageSource {
  /// Creates an [AudioMessageFileSource] that reads from [path].
  const AudioMessageFileSource(this.path);

  /// The absolute or relative file path of the audio.
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioMessageFileSource && other.path == path);

  @override
  int get hashCode => path.hashCode;
}

/// An [AudioMessageSource] backed by a bundled asset.
final class AudioMessageAssetSource extends AudioMessageSource {
  /// Creates an [AudioMessageAssetSource] for the asset called [name].
  const AudioMessageAssetSource(this.name, {this.package});

  /// The asset's name, as declared in `pubspec.yaml`.
  final String name;

  /// The package that owns the asset, or `null` for the app itself.
  final String? package;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioMessageAssetSource &&
          other.name == name &&
          other.package == package);

  @override
  int get hashCode => Object.hash(name, package);
}

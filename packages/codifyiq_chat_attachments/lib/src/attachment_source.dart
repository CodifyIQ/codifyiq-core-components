import 'package:flutter/foundation.dart';

/// Whether [source] should be loaded over the network rather than from a
/// local file.
///
/// Everything is a URL on the web, where there is no file system.
bool isRemoteSource(String source) {
  if (kIsWeb) return true;
  // By prefix, so a URL that Uri rejects, such as one with a bare `%`, is
  // still a URL.
  final lower = source.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('blob:');
}

/// Whether [source] names a bundled asset, as `flutter_chat_ui`'s own
/// bubbles read it.
bool isAssetSource(String source) => source.startsWith('assets/');

/// The file-system path of a local [source], which may be a plain path or a
/// `file://` URI.
String filePath(String source) =>
    source.startsWith('file:') ? Uri.parse(source).toFilePath() : source;

/// Where a message's source is read from, as `flutter_chat_ui`'s own bubbles
/// read it.
sealed class AttachmentSource {
  const AttachmentSource();

  /// Reads [source]: a bundled asset (`assets/...`), a URL, or a local path
  /// or `file://` URI.
  factory AttachmentSource.parse(String source) => isAssetSource(source)
      ? AssetAttachmentSource(source)
      : isRemoteSource(source)
      ? RemoteAttachmentSource(source)
      : FileAttachmentSource(filePath(source));
}

/// A bundled asset.
final class AssetAttachmentSource extends AttachmentSource {
  /// Creates an [AssetAttachmentSource] for the asset [name].
  const AssetAttachmentSource(this.name);

  /// The asset's key, such as `assets/photo.jpg`.
  final String name;
}

/// A URL, loaded over the network.
final class RemoteAttachmentSource extends AttachmentSource {
  /// Creates a [RemoteAttachmentSource] for [url].
  const RemoteAttachmentSource(this.url);

  /// The URL as the message gave it.
  final String url;

  /// [url], parsed, with any characters a URI can't hold, such as a bare
  /// `%`, escaped.
  Uri get uri => Uri.tryParse(url) ?? Uri.parse(Uri.encodeFull(url));
}

/// A file on the device.
final class FileAttachmentSource extends AttachmentSource {
  /// Creates a [FileAttachmentSource] for [path].
  const FileAttachmentSource(this.path);

  /// The file's path.
  final String path;
}

/// Whether a file with [name] and [mimeType] is a PDF.
bool isPdf(String name, String? mimeType) =>
    mimeType?.toLowerCase() == 'application/pdf' ||
    name.toLowerCase().endsWith('.pdf');

/// The upper-case extension of [name] (`PDF` for `report.pdf`), or `null`
/// when it has none.
String? fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1).toUpperCase();
}

/// Formats [bytes] for display, for example `820 KB` or `1.4 MB`.
String formatFileSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unit = 0;
  // Rounded the way it is shown, so 1023.99 KB moves up to 1 MB.
  String rounded() => size.toStringAsFixed(unit == 0 || size >= 9.95 ? 0 : 1);
  while (double.parse(rounded()) >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${rounded()} ${units[unit]}';
}

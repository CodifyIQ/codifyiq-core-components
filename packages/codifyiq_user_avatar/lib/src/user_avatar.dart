import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Signature for a function that builds an [ImageProvider] for a given photo
/// URL.
///
/// Allows callers to plug in a caching image provider (e.g. one backed by
/// `cached_network_image` or a custom disk cache) without this package taking
/// a dependency on any specific caching library. When omitted, [UserAvatar]
/// falls back to a plain [NetworkImage].
typedef UserAvatarImageProviderBuilder =
    ImageProvider Function(String photoUrl, Map<String, String>? headers);

/// A circular user avatar with a graceful fallback to initials or an icon.
///
/// Renders a [CircleAvatar] containing — in priority order — a photo from
/// [imageProvider], [photoBytes], [photoBase64], or [photoUrl] (if any is
/// supplied and loads successfully), a custom [fallbackChild] widget, initials
/// derived from [displayName] or [email], or a generic [Icons.person] glyph.
///
/// Caching is intentionally pluggable. By default the photo is loaded via
/// [NetworkImage] with no caching beyond Flutter's in-memory image cache. To
/// use a disk-backed cache (e.g. for chat surfaces that render the same
/// avatar many times), pass [imageProviderBuilder] that wraps your preferred
/// caching library:
///
/// ```dart
/// UserAvatar(
///   photoUrl: user.photoUrl,
///   displayName: user.displayName,
///   email: user.email,
///   radius: 20,
///   imageProviderBuilder: (url, headers) =>
///       CachedNetworkImageProvider(url, headers: headers),
/// )
/// ```
///
/// For a photo that is already in memory, pass [photoBytes] or [photoBase64]
/// rather than building an [ImageProvider]: this widget owns the resulting
/// [MemoryImage] and holds it stable while the bytes are unchanged, so an
/// avatar in a list that rebuilds does not re-decode its photo.
///
/// Theming follows Material 3 — the fallback background defaults to
/// [ColorScheme.secondary] and the initials/icon to [ColorScheme.onSecondary].
class UserAvatar extends StatefulWidget {
  /// Creates a [UserAvatar].
  ///
  /// At least one of [imageProvider], [photoBytes], [photoBase64], [photoUrl],
  /// [displayName], or [email] should be provided for the avatar to render
  /// meaningful content; with none of them, the generic person icon is shown.
  const UserAvatar({
    super.key,
    this.photoUrl,
    this.imageProvider,
    this.photoBytes,
    this.photoBase64,
    this.displayName,
    this.email,
    this.radius = 20.0,
    this.backgroundColor,
    this.foregroundColor,
    this.fallbackChild,
    this.headers,
    this.imageProviderBuilder,
    this.semanticLabel,
  });

  /// URL of the user's profile photo. Used when no [imageProvider],
  /// [photoBytes], or [photoBase64] is supplied; when it too is null or empty,
  /// the fallback is rendered immediately.
  final String? photoUrl;

  /// A ready-made [ImageProvider] for the avatar photo, used in place of
  /// [photoBytes], [photoBase64], [photoUrl], and [imageProviderBuilder].
  ///
  /// Use this for image sources this widget has no dedicated parameter for,
  /// such as [FileImage] or [AssetImage]. When non-null it takes precedence
  /// over the other photo sources (which are then ignored) and flows through
  /// the same circular clip, [BoxFit.cover] sizing, and error-to-initials
  /// fallback as a network photo.
  ///
  /// Providers are compared by value across rebuilds, including the bytes of a
  /// [MemoryImage] (on its own or wrapped in a [ResizeImage]), so recreating
  /// one inline in `build` does not force a re-decode. For in-memory photos
  /// prefer [photoBytes] or [photoBase64], which let the widget own the
  /// [MemoryImage] instance and keep it stable for Flutter's [ImageCache].
  final ImageProvider? imageProvider;

  /// Raw encoded bytes of the user's profile photo (PNG, JPEG, …), rendered
  /// via an internally managed [MemoryImage].
  ///
  /// Used when [imageProvider] is null, and takes precedence over
  /// [photoBase64] and [photoUrl]. The bytes are compared by value, and the
  /// underlying [MemoryImage] — and therefore its decoded frame in Flutter's
  /// [ImageCache] — is reused whenever they are unchanged, so allocating a
  /// fresh list inside `build` is safe. Holding one list in state is free
  /// (the comparison short-circuits on identity); a fresh copy costs a
  /// byte-by-byte comparison per rebuild, still far cheaper than a decode but
  /// worth avoiding for large photos in a frequently rebuilt list.
  final Uint8List? photoBytes;

  /// The user's profile photo as a base64-encoded string — the shape a photo
  /// usually arrives in from an OAuth provider or a JSON API.
  ///
  /// Used when [imageProvider] and [photoBytes] are null, and takes precedence
  /// over [photoUrl]. A `data:` URI prefix (e.g.
  /// `data:image/png;base64,iVBOR…`) is accepted and stripped. The string is
  /// compared as a string across rebuilds, so the decoded frame survives them.
  /// A string that is not valid base64 never throws — it is treated as no
  /// photo at all, so the avatar falls through to [photoUrl] if one was given
  /// and to initials otherwise.
  final String? photoBase64;

  /// Display name used to derive initials when [photoUrl] is unavailable or
  /// fails to load. Two-word names yield first+last initials; single-word
  /// names yield the first two characters. Bracketed qualifiers such as
  /// `"(Contractor)"` or `"[Acme Corp]"` are ignored — see [initialsFor].
  final String? displayName;

  /// Email address used to derive initials when [displayName] is not
  /// provided. The portion before the `@` is used.
  final String? email;

  /// Radius of the circular avatar, in logical pixels.
  final double radius;

  /// Background color of the fallback circle. Defaults to
  /// `Theme.of(context).colorScheme.secondary`.
  final Color? backgroundColor;

  /// Color of the fallback initials text or icon. Defaults to
  /// `Theme.of(context).colorScheme.onSecondary`.
  final Color? foregroundColor;

  /// Custom widget rendered as the child of the fallback `CircleAvatar` in
  /// place of initials or the default person icon. The surrounding circle
  /// (using [radius] and [backgroundColor]) is still rendered around it.
  final Widget? fallbackChild;

  /// Optional HTTP headers forwarded to the image provider — typically used
  /// for `Authorization` tokens when the photo endpoint is protected.
  final Map<String, String>? headers;

  /// Builds the [ImageProvider] for [photoUrl]. When omitted, a plain
  /// [NetworkImage] is used. Supply this to integrate a disk-backed cache.
  final UserAvatarImageProviderBuilder? imageProviderBuilder;

  /// Accessibility label announced by assistive technologies. When omitted,
  /// the widget falls back to [displayName], then [email], then the literal
  /// string `'User avatar'`.
  final String? semanticLabel;

  /// Matches a bracketed qualifier — `(…)`, `[…]`, or `{…}` — anywhere in a
  /// display name. Compiled once; [initialsFor] runs on every avatar build.
  static final RegExp _qualifierPattern = RegExp(
    r'\([^)]*\)|\[[^\]]*\]|\{[^}]*\}',
  );

  /// Computes the initials that the fallback would render for the given
  /// [displayName] and [email]. Exposed for callers that want to mirror the
  /// avatar's initials elsewhere in their UI (e.g. in a menu header).
  ///
  /// Bracketed qualifiers in [displayName] — e.g. `"(Contractor)"`,
  /// `"[Acme Corp]"`, `"{External}"`, common in enterprise and government
  /// directories — are stripped before deriving initials, so
  /// `"Java Joe (Contractor)"` yields `"JJ"` rather than `"J("`. A name that is
  /// *entirely* a qualifier falls through to the [email].
  static String initialsFor({String? displayName, String? email}) {
    String firstGrapheme(String s) => s.characters.first;
    String firstTwoGraphemes(String s) => s.characters.take(2).toString();

    // Replace bracketed segments with a space so they neither contribute
    // initials nor fuse adjacent words (e.g. "A(x)B" → "A B", not "AB").
    final cleanedName = displayName?.replaceAll(_qualifierPattern, ' ').trim();

    if (cleanedName != null && cleanedName.isNotEmpty) {
      final parts = cleanedName.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${firstGrapheme(parts.first)}${firstGrapheme(parts.last)}'
            .toUpperCase();
      }
      return firstTwoGraphemes(parts.first).toUpperCase();
    }
    if (email != null && email.isNotEmpty) {
      final user = email.split('@').first;
      if (user.isEmpty) return '';
      return firstTwoGraphemes(user).toUpperCase();
    }
    return '';
  }

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  ImageProvider? _image;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _image = _buildImage();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl ||
        !_sameProvider(oldWidget.imageProvider, widget.imageProvider) ||
        !listEquals(oldWidget.photoBytes, widget.photoBytes) ||
        oldWidget.photoBase64 != widget.photoBase64 ||
        !mapEquals(oldWidget.headers, widget.headers) ||
        oldWidget.imageProviderBuilder != widget.imageProviderBuilder) {
      setState(() {
        _image = _buildImage();
        _hasError = false;
      });
    }
  }

  /// Whether two providers describe the same image, treating [MemoryImage]
  /// bytes by value.
  ///
  /// `MemoryImage`'s own `==` compares its `Uint8List` by identity, so an
  /// equal-but-newly-allocated provider would otherwise read as a change and
  /// force a re-decode (it also misses [ImageCache], which is keyed on the
  /// same equality). [ResizeImage] is unwrapped first, since its equality
  /// delegates to the provider it wraps — a natural thing to wrap an avatar
  /// photo in, to decode it at display size.
  static bool _sameProvider(ImageProvider? a, ImageProvider? b) {
    if (a is ResizeImage && b is ResizeImage) {
      return a.width == b.width &&
          a.height == b.height &&
          a.allowUpscaling == b.allowUpscaling &&
          a.policy == b.policy &&
          _sameProvider(a.imageProvider, b.imageProvider);
    }
    if (a is MemoryImage && b is MemoryImage) {
      return a.scale == b.scale && listEquals(a.bytes, b.bytes);
    }
    return a == b;
  }

  ImageProvider? _buildImage() {
    // An explicit provider wins — it may be a non-URL source (FileImage,
    // AssetImage, …), so it is not gated on photoUrl.
    if (widget.imageProvider != null) return widget.imageProvider;
    final bytes = widget.photoBytes ?? _decodeBase64(widget.photoBase64);
    if (bytes != null) {
      // Reuse the existing MemoryImage when the bytes are unchanged, so the
      // provider stays identical for ImageCache across rebuilds.
      final current = _image;
      if (current is MemoryImage && listEquals(current.bytes, bytes)) {
        return current;
      }
      return MemoryImage(bytes);
    }
    final url = widget.photoUrl;
    if (url == null || url.isEmpty) return null;
    final builder = widget.imageProviderBuilder;
    return builder != null
        ? builder(url, widget.headers)
        : NetworkImage(url, headers: widget.headers);
  }

  /// Decodes [source], tolerating a `data:` URI prefix. Returns null when the
  /// string is absent, empty, or not valid base64 — the avatar then falls back
  /// to initials rather than throwing.
  static Uint8List? _decodeBase64(String? source) {
    if (source == null || source.isEmpty) return null;
    final comma = source.startsWith('data:') ? source.indexOf(',') : -1;
    final payload = comma == -1 ? source : source.substring(comma + 1);
    try {
      return base64Decode(payload);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = widget.backgroundColor ?? theme.colorScheme.secondary;
    final foreground = widget.foregroundColor ?? theme.colorScheme.onSecondary;

    final Widget avatar = (_image == null || _hasError)
        ? _buildFallback(background, foreground)
        : CircleAvatar(
            radius: widget.radius,
            backgroundColor: Colors.transparent,
            child: ClipOval(
              child: Image(
                image: _image!,
                fit: BoxFit.cover,
                width: widget.radius * 2,
                height: widget.radius * 2,
                errorBuilder: (context, error, stackTrace) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _hasError = true);
                  });
                  return _buildFallback(background, foreground);
                },
              ),
            ),
          );

    return Semantics(
      label:
          widget.semanticLabel ??
          widget.displayName ??
          widget.email ??
          'User avatar',
      image: true,
      container: true,
      child: ExcludeSemantics(child: avatar),
    );
  }

  Widget _buildFallback(Color background, Color foreground) {
    final initials = UserAvatar.initialsFor(
      displayName: widget.displayName,
      email: widget.email,
    );
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: background,
      child:
          widget.fallbackChild ??
          (initials.isNotEmpty
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: widget.radius * 0.8,
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                )
              : Icon(
                  Icons.person,
                  size: widget.radius * 1.2,
                  color: foreground,
                )),
    );
  }
}

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
/// Renders a [CircleAvatar] containing — in priority order — an explicit
/// [imageProvider] or a photo loaded from [photoUrl] (if either is supplied
/// and loads successfully), a custom [fallbackChild] widget, initials derived
/// from [displayName] or [email], or a generic [Icons.person] glyph.
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
/// Theming follows Material 3 — the fallback background defaults to
/// [ColorScheme.secondary] and the initials/icon to [ColorScheme.onSecondary].
class UserAvatar extends StatefulWidget {
  /// Creates a [UserAvatar].
  ///
  /// At least one of [imageProvider], [photoUrl], [displayName], or [email]
  /// should be provided for the avatar to render meaningful content; with none
  /// of them, the generic person icon is shown.
  const UserAvatar({
    super.key,
    this.photoUrl,
    this.imageProvider,
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

  /// URL of the user's profile photo. When null or empty (and [imageProvider]
  /// is also null), the fallback is rendered immediately.
  final String? photoUrl;

  /// A ready-made [ImageProvider] for the avatar photo, used in place of
  /// [photoUrl] and [imageProviderBuilder].
  ///
  /// Use this for non-URL image sources such as [MemoryImage], [FileImage], or
  /// [AssetImage]. When non-null it takes precedence over [photoUrl] /
  /// [imageProviderBuilder] (which are then ignored) and flows through the
  /// same circular clip, [BoxFit.cover] sizing, and error-to-initials fallback
  /// as a network photo.
  ///
  /// In list contexts (e.g. a chat roster) pass a *stable* provider instance
  /// so Flutter's image cache can dedupe it across rebuilds. This matters most
  /// for [MemoryImage], whose equality compares the underlying bytes by
  /// identity — hold the [MemoryImage] (or its `Uint8List`) in state rather
  /// than allocating it inside `build`, or the image re-decodes every frame.
  /// [NetworkImage] and [FileImage] compare by value, so they are safe to
  /// recreate inline.
  final ImageProvider? imageProvider;

  /// Display name used to derive initials when [photoUrl] is unavailable or
  /// fails to load. Two-word names yield first+last initials; single-word
  /// names yield the first two characters. Parenthetical qualifiers such as
  /// `"(Contractor)"` are ignored — see [initialsFor].
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

  /// Computes the initials that the fallback would render for the given
  /// [displayName] and [email]. Exposed for callers that want to mirror the
  /// avatar's initials elsewhere in their UI (e.g. in a menu header).
  ///
  /// Parenthetical qualifiers in [displayName] — e.g. `"(Contractor)"`,
  /// `"(Acme Corp)"`, common in enterprise and government directories — are
  /// stripped before deriving initials, so `"Java Joe (Contractor)"` yields
  /// `"JJ"` rather than `"J("`. A name that is *entirely* parenthetical falls
  /// through to the [email].
  static String initialsFor({String? displayName, String? email}) {
    String firstGrapheme(String s) => s.characters.first;
    String firstTwoGraphemes(String s) => s.characters.take(2).toString();

    // Replace "(…)" segments with a space so they neither contribute initials
    // nor fuse adjacent words (e.g. "A(x)B" → "A B", not "AB").
    final cleanedName = displayName
        ?.replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .trim();

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
        oldWidget.imageProvider != widget.imageProvider ||
        !mapEquals(oldWidget.headers, widget.headers) ||
        oldWidget.imageProviderBuilder != widget.imageProviderBuilder) {
      setState(() {
        _image = _buildImage();
        _hasError = false;
      });
    }
  }

  ImageProvider? _buildImage() {
    // An explicit provider wins — it may be a non-URL source (MemoryImage,
    // FileImage, …), so it is not gated on photoUrl.
    if (widget.imageProvider != null) return widget.imageProvider;
    final url = widget.photoUrl;
    if (url == null || url.isEmpty) return null;
    final builder = widget.imageProviderBuilder;
    return builder != null
        ? builder(url, widget.headers)
        : NetworkImage(url, headers: widget.headers);
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

import 'package:flutter/material.dart';

/// Signature for a function that builds an [ImageProvider] for a given photo
/// URL.
///
/// Allows callers to plug in a caching image provider (e.g. one backed by
/// `cached_network_image` or a custom disk cache) without this package taking
/// a dependency on any specific caching library. When omitted, [UserAvatar]
/// falls back to a plain [NetworkImage].
typedef UserAvatarImageProviderBuilder = ImageProvider Function(
  String photoUrl,
  Map<String, String>? headers,
);

/// A circular user avatar with a graceful fallback to initials or an icon.
///
/// Renders a [CircleAvatar] containing — in priority order — the user's photo
/// (if [photoUrl] is supplied and loads successfully), a custom [fallback]
/// widget, initials derived from [displayName] or [email], or a generic
/// [Icons.person] glyph.
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
  /// At least one of [photoUrl], [displayName], or [email] should be provided
  /// for the avatar to render meaningful content; with none of them, the
  /// generic person icon is shown.
  const UserAvatar({
    super.key,
    this.photoUrl,
    this.displayName,
    this.email,
    this.radius = 20.0,
    this.backgroundColor,
    this.foregroundColor,
    this.fallback,
    this.headers,
    this.imageProviderBuilder,
  });

  /// URL of the user's profile photo. When null or empty, the fallback is
  /// rendered immediately.
  final String? photoUrl;

  /// Display name used to derive initials when [photoUrl] is unavailable or
  /// fails to load. Two-word names yield first+last initials; single-word
  /// names yield the first two characters.
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

  /// Custom widget rendered in the fallback circle in place of initials or
  /// the default person icon.
  final Widget? fallback;

  /// Optional HTTP headers forwarded to the image provider — typically used
  /// for `Authorization` tokens when the photo endpoint is protected.
  final Map<String, String>? headers;

  /// Builds the [ImageProvider] for [photoUrl]. When omitted, a plain
  /// [NetworkImage] is used. Supply this to integrate a disk-backed cache.
  final UserAvatarImageProviderBuilder? imageProviderBuilder;

  /// Computes the initials that the fallback would render for the given
  /// [displayName] and [email]. Exposed for callers that want to mirror the
  /// avatar's initials elsewhere in their UI (e.g. in a menu header).
  static String initialsFor({String? displayName, String? email}) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      final only = parts.first;
      return (only.length > 1 ? only.substring(0, 2) : only).toUpperCase();
    }
    if (email != null && email.isNotEmpty) {
      final user = email.split('@').first;
      if (user.isEmpty) return '';
      return (user.length > 1 ? user.substring(0, 2) : user).toUpperCase();
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
        oldWidget.headers != widget.headers ||
        oldWidget.imageProviderBuilder != widget.imageProviderBuilder) {
      setState(() {
        _image = _buildImage();
        _hasError = false;
      });
    }
  }

  ImageProvider? _buildImage() {
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

    if (_image == null || _hasError) {
      return _buildFallback(background, foreground);
    }

    return CircleAvatar(
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
  }

  Widget _buildFallback(Color background, Color foreground) {
    final initials = UserAvatar.initialsFor(
      displayName: widget.displayName,
      email: widget.email,
    );
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: background,
      child: widget.fallback ??
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

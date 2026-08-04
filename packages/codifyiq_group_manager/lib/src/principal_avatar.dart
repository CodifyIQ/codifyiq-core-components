import 'package:codifyiq_user_avatar/codifyiq_user_avatar.dart';
import 'package:flutter/material.dart';

import 'group_color.dart';
import 'principal.dart';

/// Signature for a function that builds an [ImageProvider] for a principal's
/// photo URL.
///
/// Lets callers plug in a caching or authenticating image provider (e.g. one
/// backed by `cached_network_image`) without this package depending on any
/// specific library. When omitted, a plain [NetworkImage] is used.
///
/// This is an alias of `UserAvatarImageProviderBuilder`, so the same builder can
/// be handed to a member avatar here and to a `UserAvatar` elsewhere in the app.
typedef PrincipalAvatarImageProviderBuilder = UserAvatarImageProviderBuilder;

/// A small circular badge representing a [Principal].
///
/// Falls back in three steps: the principal's photo — [Principal.imageProvider]
/// if supplied, otherwise [Principal.imageUrl] — when it loads, then its
/// [Principal.icon], then the initials derived from its [Principal.name]. A
/// photo that fails to load reverts to the step below it rather than leaving an
/// empty circle.
///
/// This is a thin wrapper over `UserAvatar` from the sibling
/// `codifyiq_user_avatar` package — the same widget your profile and member
/// screens already use. Photos, initials (see `UserAvatar.initialsFor`, which
/// skips bracketed qualifiers such as `"Alice [Contractor]"`), and the generic
/// person glyph therefore all render exactly as they do everywhere else in your
/// app, and cannot drift from it. Loading stays pluggable: pass [headers] when
/// the photo endpoint is protected, and [imageProviderBuilder] to route the
/// fetch through a cache. Without them a member's photo is fetched cold and
/// unauthenticated, which is the usual reason a member shows initials on one
/// screen and a photo on another.
///
/// What this adds over a bare `UserAvatar` is the group palette and the
/// service-account glyph: the fallback circle is tinted with a [GroupColor] role
/// derived from the principal's id, resolved against the current theme — the
/// same palette groups use, so a member chip sits beside a group chip without
/// introducing a second, unrelated set of accents. Foreground contrast comes
/// from the role's matching `on*` token, so it is always correct.
class PrincipalAvatar extends StatelessWidget {
  /// Creates a [PrincipalAvatar] for [principal].
  const PrincipalAvatar({
    super.key,
    required this.principal,
    this.radius = 20.0,
    this.headers,
    this.imageProviderBuilder,
  });

  /// The principal to represent.
  final Principal principal;

  /// Radius of the circle, in logical pixels.
  final double radius;

  /// Optional HTTP headers forwarded to the image provider — typically an
  /// `Authorization` token when the photo endpoint is protected. Without them
  /// a protected photo fails to load and the avatar falls back to initials.
  final Map<String, String>? headers;

  /// Builds the [ImageProvider] for [Principal.imageUrl]. When omitted, a plain
  /// [NetworkImage] is used. Supply this to share a disk-backed cache with the
  /// rest of the app so the same member's photo is not refetched per screen.
  /// Ignored when the principal carries a [Principal.imageProvider] of its own.
  ///
  /// Pass a *stable* reference — a top-level or static function, or a callback
  /// held in state — rather than a closure allocated inside `build`. The
  /// builder is re-invoked whenever it compares unequal to the previous one, so
  /// a fresh closure per frame refetches and re-decodes the photo on every
  /// rebuild.
  final PrincipalAvatarImageProviderBuilder? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (:background, :foreground) = GroupColor.auto(
      principal.id,
    ).resolve(scheme);

    final icon = principal.icon;

    return UserAvatar(
      photoUrl: principal.imageUrl,
      imageProvider: principal.imageProvider,
      // Initials and the person-glyph fallback are UserAvatar's to derive —
      // a member's avatar must not read differently here than on a profile or
      // member screen.
      displayName: principal.name,
      radius: radius,
      backgroundColor: background,
      foregroundColor: foreground,
      headers: headers,
      imageProviderBuilder: imageProviderBuilder,
      // The only fallback this package owns: a service account's glyph, which
      // stands in for initials no person avatar would have.
      fallbackChild: icon != null
          ? Icon(icon, size: radius, color: foreground)
          : null,
    );
  }
}

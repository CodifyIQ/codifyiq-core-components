import 'package:flutter/widgets.dart';

/// A subject that can be a member of a [Group] — a user, a service account, or
/// anything else the host application authorizes.
///
/// This is a **presentational** model, not a user record. The package needs a
/// name and an avatar to render a member row or chip; it deliberately carries
/// nothing else. Assignments are still keyed by [id] alone, so
/// [GroupManagerController] never stores a [Principal] — the caller owns the
/// roster and passes it to whichever widget needs to display members, exactly
/// as it passes the [Group] catalog.
///
/// Map your own user type onto it at the widget boundary:
///
/// ```dart
/// final roster = [
///   for (final user in myUsers)
///     Principal(
///       id: user.uid,
///       name: user.displayName,
///       description: user.email,
///       imageUrl: user.photoUrl,
///     ),
/// ];
/// ```
///
/// Principals are immutable; produce modified copies with [copyWith]. Equality
/// is by value across every field so that list widgets rebuild only when a
/// principal actually changes.
@immutable
class Principal {
  /// Creates a [Principal].
  ///
  /// [id] must be stable and unique within a roster — it is what the controller
  /// and assignment APIs key on, and it must match the principal id used with
  /// [GroupManagerController.groupsFor] and friends. [name] is the
  /// human-readable label shown in the UI.
  const Principal({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.imageProvider,
    this.icon,
  });

  /// Stable, unique identifier used to reference the principal in assignments.
  final String id;

  /// Human-readable label shown in lists, chips, and pickers.
  final String name;

  /// Optional secondary line — typically an email address or job title.
  final String? description;

  /// Optional profile photo. When it loads, it replaces the initials or [icon];
  /// when it fails to load, widgets fall back to them, so a broken URL degrades
  /// gracefully rather than leaving a blank circle.
  final String? imageUrl;

  /// A ready-made [ImageProvider] for the profile photo, used in place of
  /// [imageUrl].
  ///
  /// Use this for photos that do not come from a URL the widget can fetch —
  /// bytes already in memory ([MemoryImage], e.g. a base64 payload from your
  /// directory or backend), a downloaded file ([FileImage]), or a bundled
  /// [AssetImage]. When non-null it takes precedence over [imageUrl] (and any
  /// `imageProviderBuilder`), and renders through exactly the same circular
  /// clip and fallback behaviour as a network photo — this is the same escape
  /// hatch `UserAvatar.imageProvider` offers in `codifyiq_user_avatar`.
  ///
  /// ```dart
  /// Principal(
  ///   id: user.uid,
  ///   name: user.displayName,
  ///   imageProvider: MemoryImage(base64Decode(user.photoBase64)),
  /// )
  /// ```
  ///
  /// Pass a *stable* instance in list contexts. [MemoryImage] equality compares
  /// its byte list by identity, so hold it in state rather than allocating it
  /// inside `build`, or the photo re-decodes on every rebuild. [NetworkImage],
  /// [FileImage], and [AssetImage] compare by value and are safe to recreate.
  final ImageProvider? imageProvider;

  /// Optional glyph used in place of initials when there is no photo —
  /// e.g. a robot glyph for a service account.
  final IconData? icon;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass [clearDescription], [clearImageUrl], [clearImageProvider], or
  /// [clearIcon] to explicitly reset those nullable fields back to `null`.
  Principal copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    ImageProvider? imageProvider,
    IconData? icon,
    bool clearDescription = false,
    bool clearImageUrl = false,
    bool clearImageProvider = false,
    bool clearIcon = false,
  }) {
    return Principal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      imageProvider: clearImageProvider
          ? null
          : (imageProvider ?? this.imageProvider),
      icon: clearIcon ? null : (icon ?? this.icon),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Principal &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          imageUrl == other.imageUrl &&
          imageProvider == other.imageProvider &&
          icon == other.icon;

  @override
  int get hashCode =>
      Object.hash(id, name, description, imageUrl, imageProvider, icon);

  @override
  String toString() => 'Principal(id: $id, name: $name)';
}

import 'package:flutter/foundation.dart';
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
    this.photoBytes,
    this.photoBase64,
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

  /// Raw encoded bytes of the profile photo (PNG, JPEG, …), for a photo already
  /// in memory rather than behind a URL.
  ///
  /// Used when [imageProvider] is null, and takes precedence over [photoBase64]
  /// and [imageUrl]. The avatar widget owns the resulting `MemoryImage` and
  /// reuses it while the bytes are unchanged, so building the list inline is
  /// safe — the photo does not re-decode when a member list rebuilds. Bytes are
  /// compared by value here too, so a fresh copy of the same photo leaves the
  /// [Principal] equal to its predecessor.
  final Uint8List? photoBytes;

  /// The profile photo as a base64-encoded string — the shape a photo usually
  /// arrives in from an OAuth provider, a directory, or a JSON API.
  ///
  /// Used when [imageProvider] and [photoBytes] are null, and takes precedence
  /// over [imageUrl]. A `data:` URI prefix is accepted and stripped, and a
  /// string that is not valid base64 falls through to [imageUrl] (then to the
  /// [icon] or initials) rather than throwing. Prefer this over decoding the
  /// string yourself:
  ///
  /// ```dart
  /// Principal(
  ///   id: user.uid,
  ///   name: user.displayName,
  ///   photoBase64: user.photoBase64,
  /// )
  /// ```
  final String? photoBase64;

  /// A ready-made [ImageProvider] for the profile photo, used in place of every
  /// other photo source.
  ///
  /// Reach for this only for sources the fields above do not cover — a
  /// downloaded [FileImage] or a bundled [AssetImage]. For an in-memory photo
  /// prefer [photoBytes] or [photoBase64], which let the avatar own the
  /// `MemoryImage` and keep it stable for Flutter's image cache.
  ///
  /// Pass a *stable* instance in list contexts: [Principal] equality compares
  /// providers with `==`, and a [MemoryImage] compares its byte list by
  /// identity, so one allocated inside `build` makes every principal compare
  /// unequal and churns the list. [FileImage] and [AssetImage] compare by value
  /// and are safe to recreate.
  final ImageProvider? imageProvider;

  /// Optional glyph used in place of initials when there is no photo —
  /// e.g. a robot glyph for a service account.
  final IconData? icon;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass [clearDescription], [clearImageUrl], [clearPhotoBytes],
  /// [clearPhotoBase64], [clearImageProvider], or [clearIcon] to explicitly
  /// reset those nullable fields back to `null`.
  Principal copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    Uint8List? photoBytes,
    String? photoBase64,
    ImageProvider? imageProvider,
    IconData? icon,
    bool clearDescription = false,
    bool clearImageUrl = false,
    bool clearPhotoBytes = false,
    bool clearPhotoBase64 = false,
    bool clearImageProvider = false,
    bool clearIcon = false,
  }) {
    return Principal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      photoBytes: clearPhotoBytes ? null : (photoBytes ?? this.photoBytes),
      photoBase64: clearPhotoBase64 ? null : (photoBase64 ?? this.photoBase64),
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
          // By value, not by identity: a photo re-read from your backend is a
          // fresh list holding the same bytes, and treating that as a change
          // would rebuild every row it appears in.
          listEquals(photoBytes, other.photoBytes) &&
          photoBase64 == other.photoBase64 &&
          imageProvider == other.imageProvider &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    imageUrl,
    // Length only: equal byte lists always agree on it, and hashing a whole
    // photo on every lookup would cost more than the collisions it avoids.
    photoBytes?.length,
    photoBase64,
    imageProvider,
    icon,
  );

  @override
  String toString() => 'Principal(id: $id, name: $name)';
}

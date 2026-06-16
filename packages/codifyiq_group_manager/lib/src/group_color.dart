import 'package:flutter/material.dart';

/// A theme-derived accent for a [Group].
///
/// Rather than storing a concrete [Color] — which can't follow light/dark or a
/// rebranded [ColorScheme] — a group references one of Material 3's container
/// roles. The actual color is resolved against the ambient theme at render
/// time via [resolve], so a group's accent always harmonizes with the app and
/// adapts automatically when the theme changes.
enum GroupColor {
  /// The primary container role.
  primary,

  /// The secondary container role.
  secondary,

  /// The tertiary container role.
  tertiary,

  /// A neutral, low-emphasis surface role.
  neutral;

  /// The roles eligible for automatic per-group assignment. Excludes
  /// [neutral], so an auto-colored group always gets a distinct accent;
  /// [neutral] remains available as an explicit, deliberately muted choice.
  static const List<GroupColor> _autoRoles = <GroupColor>[
    primary,
    secondary,
    tertiary,
  ];

  /// Deterministically derives a stable accent for the group with [id].
  ///
  /// The same id always maps to the same role (within and across runs), so a
  /// group's auto color doesn't shuffle on rebuild. Used when a group has no
  /// explicit [GroupColor].
  static GroupColor auto(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _autoRoles[hash % _autoRoles.length];
  }

  /// Resolves this role to a background/foreground pair from [scheme].
  ///
  /// The foreground is the role's matching `on*` token, so contrast is correct
  /// in every theme without any luminance guessing.
  ({Color background, Color foreground}) resolve(ColorScheme scheme) {
    return switch (this) {
      GroupColor.primary => (
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
      ),
      GroupColor.secondary => (
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      ),
      GroupColor.tertiary => (
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      ),
      GroupColor.neutral => (
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
      ),
    };
  }
}

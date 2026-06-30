import 'dart:convert';

import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:codifyiq_user_avatar/codifyiq_user_avatar.dart';
import 'package:flutter/material.dart';

/// Example page demonstrating [UserAvatar].
///
/// Shows the avatar in three states: a successfully loaded network photo,
/// initials derived from a display name, and initials derived from an email
/// fallback. Also illustrates radius and color overrides, plus supplying a
/// non-URL image via [UserAvatar.imageProvider].
class UserAvatarExample extends StatelessWidget {
  /// Creates a [UserAvatarExample].
  const UserAvatarExample({super.key});

  /// A tiny in-memory PNG (a solid red 1×1 swatch), decoded once and held as a
  /// stable [MemoryImage] instance.
  ///
  /// Keeping a single instance — rather than allocating `MemoryImage(...)`
  /// inside `build` — lets Flutter's image cache dedupe it across rebuilds,
  /// the recommended pattern for `MemoryImage` in list/chat contexts (see the
  /// `imageProvider` dartdoc).
  static final MemoryImage _inMemoryAvatar = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
      'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    ),
  );

  static const List<_DemoUser> _users = [
    _DemoUser(
      label: 'Photo (loads from picsum)',
      photoUrl: 'https://picsum.photos/id/1005/200/200',
      displayName: 'Ada Lovelace',
      email: 'ada@example.com',
    ),
    _DemoUser(
      label: 'Initials from full name',
      displayName: 'Grace Hopper',
      email: 'grace@example.com',
    ),
    _DemoUser(label: 'Initials from single name', displayName: 'Linus'),
    _DemoUser(
      label: 'Initials from a kanji name (葛飾 北斎 → 葛北)',
      displayName: '葛飾 北斎',
    ),
    _DemoUser(
      label: 'Name with a parenthetical suffix (Java Joe (Contractor) → JJ)',
      displayName: 'Java Joe (Contractor)',
    ),
    _DemoUser(
      label: 'Initials from email (no name)',
      email: 'kathleen.booth@example.com',
    ),
    _DemoUser(
      label: 'Bad URL → graceful fallback to initials',
      photoUrl: 'https://invalid.example.com/nope.png',
      displayName: 'Margaret Hamilton',
    ),
    _DemoUser(label: 'No info → generic person icon'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Avatar Example'),
        actions: const [BrightnessButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Default radius (20) with photo, initials, and icon fallbacks:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final user in _users) _AvatarRow(user: user),
            const Divider(height: 32),
            Text(
              'Size and color overrides:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const UserAvatar(displayName: 'Tiny User', radius: 12),
                const SizedBox(width: 16),
                const UserAvatar(displayName: 'Medium User', radius: 24),
                const SizedBox(width: 16),
                const UserAvatar(displayName: 'Large User', radius: 40),
                const SizedBox(width: 16),
                UserAvatar(
                  displayName: 'Custom Colors',
                  radius: 40,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Non-URL image source (MemoryImage via imageProvider):',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                UserAvatar(
                  imageProvider: _inMemoryAvatar,
                  displayName: 'In Memory',
                  radius: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'imageProvider takes precedence over photoUrl and a builder, '
                    'and flows through the same circular-clip, cover-fit, and '
                    'error-to-initials fallback as a network photo — here a '
                    'red MemoryImage swatch with no URL at all.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.user});

  final _DemoUser user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          UserAvatar(
            photoUrl: user.photoUrl,
            displayName: user.displayName,
            email: user.email,
            radius: 24,
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(user.label)),
        ],
      ),
    );
  }
}

class _DemoUser {
  const _DemoUser({
    required this.label,
    this.photoUrl,
    this.displayName,
    this.email,
  });

  final String label;
  final String? photoUrl;
  final String? displayName;
  final String? email;
}

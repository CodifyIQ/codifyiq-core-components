import 'package:codifyiq_core_components/widgets/user_avatar.dart';
import 'package:flutter/material.dart';

/// Example page demonstrating [UserAvatar].
///
/// Shows the avatar in three states: a successfully loaded network photo,
/// initials derived from a display name, and initials derived from an email
/// fallback. Also illustrates radius and color overrides.
class UserAvatarExample extends StatelessWidget {
  /// Creates a [UserAvatarExample].
  const UserAvatarExample({super.key});

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
    _DemoUser(
      label: 'Initials from single name',
      displayName: 'Linus',
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
    _DemoUser(
      label: 'No info → generic person icon',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('User Avatar Example')),
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

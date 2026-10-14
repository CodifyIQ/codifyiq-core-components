import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
import 'package:material_ui/material_ui.dart';

/// Example page demonstrating the two ways to offer the Light / Dark / System
/// choice: a standalone [BrightnessButton] and a [BrightnessSubmenu] inside an
/// app's existing menu.
///
/// Both live in this page's app bar: the [BrightnessButton] (the same one on
/// every catalog page), and a [BrightnessSubmenu] inside the overflow menu next
/// to it.
class BrightnessButtonExample extends StatelessWidget {
  /// Creates a [BrightnessButtonExample].
  const BrightnessButtonExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brightness Button Example'),
        actions: [
          const BrightnessButton(),
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.person_outline),
                onPressed: () {},
                child: const Text('Profile'),
              ),
              const BrightnessSubmenu(),
              const Divider(),
              MenuItemButton(
                leadingIcon: const Icon(Icons.logout),
                onPressed: () {},
                child: const Text('Sign out'),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More',
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('As a button', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'BrightnessButton is the icon in the app bar, as on every page '
              'of this catalog. Its icon reflects the current mode; tap it to '
              'choose Light, Dark, or System.',
              style: theme.textTheme.bodyMedium,
            ),
            const Divider(height: 32),
            Text('In an existing menu', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Already have an account or overflow menu? Open the ⋮ menu in '
              'the app bar: BrightnessSubmenu adds the same choice as a '
              '"Theme" submenu, so the app bar needs no extra button. To list '
              'the three items directly in a menu instead, spread '
              'brightnessMenuItems(context) into its children.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

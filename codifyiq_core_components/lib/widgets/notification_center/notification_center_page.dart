import 'package:flutter/material.dart';

import 'notification_center_controller.dart';
import 'notification_center_panel.dart';

/// Full-screen page wrapping a [NotificationCenterPanel].
///
/// Intended for narrow viewports where a dropdown menu would be cramped.
/// [NotificationBellButton] pushes this page automatically on screens
/// narrower than its `mobileBreakpoint`.
///
/// The page provides a standard [AppBar] with a back button, the panel
/// title, and a "Clear completed" action that appears whenever there are
/// completed items. The panel itself is rendered with its in-panel header
/// hidden to avoid duplicating the title.
class NotificationCenterPage extends StatelessWidget {
  /// Creates a [NotificationCenterPage].
  const NotificationCenterPage({
    super.key,
    required this.controller,
    this.title = 'Notifications',
    this.emptyPlaceholder,
  });

  /// Backing controller.
  final NotificationCenterController controller;

  /// App-bar title.
  final String title;

  /// Widget shown when the controller is empty.
  final Widget? emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [_ClearCompletedAction(controller: controller)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: NotificationCenterPanel(
            controller: controller,
            maxHeight: double.infinity,
            emptyPlaceholder: emptyPlaceholder,
            showHeader: false,
          ),
        ),
      ),
    );
  }
}

class _ClearCompletedAction extends StatelessWidget {
  const _ClearCompletedAction({required this.controller});

  final NotificationCenterController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.structureListenable,
      builder: (context, _) {
        final hasAnyCompleted =
            controller.failed.isNotEmpty || controller.succeeded.isNotEmpty;
        if (!hasAnyCompleted) return const SizedBox.shrink();
        return TextButton(
          onPressed: controller.clearCompleted,
          child: const Text('Clear completed'),
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:codifyiq_notification_center/codifyiq_notification_center.dart';
import 'package:flutter/material.dart';

/// Demo for [NotificationBellButton] and [NotificationCenterController].
///
/// Simulates Play-Store-style long-running tasks: a button kicks off a fake
/// "download" that ticks progress on a timer and finishes with either
/// success or failure. The bell in the app bar tracks them all and can be
/// opened while the work continues in the background.
class NotificationCenterExample extends StatefulWidget {
  /// Creates a [NotificationCenterExample].
  const NotificationCenterExample({super.key});

  @override
  State<NotificationCenterExample> createState() =>
      _NotificationCenterExampleState();
}

class _NotificationCenterExampleState extends State<NotificationCenterExample> {
  final NotificationCenterController _notifications =
      NotificationCenterController();
  final Random _random = Random();
  int _taskCounter = 0;
  final List<Timer> _timers = [];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _notifications.dispose();
    super.dispose();
  }

  void _startFakeDownload({bool willFail = false}) {
    _taskCounter += 1;
    final id = 'task-$_taskCounter';
    final title = 'Downloading file_$_taskCounter.zip';
    _notifications.start(
      id: id,
      title: title,
      description: 'Starting…',
      progress: 0,
    );
    double progress = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      progress += 0.05 + _random.nextDouble() * 0.1;
      if (progress >= 1.0) {
        t.cancel();
        _timers.remove(t);
        if (willFail) {
          _notifications.fail(
            id,
            description: 'Network error while downloading.',
            action: NotificationItemAction(
              label: 'Retry',
              onPressed: () => _startFakeDownload(willFail: false),
            ),
          );
        } else {
          _notifications.complete(
            id,
            description: 'Saved to Downloads/file_$_taskCounter.zip',
            action: NotificationItemAction(
              label: 'Open',
              onPressed: () {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening file_$_taskCounter.zip')),
                );
              },
            ),
          );
        }
      } else {
        _notifications.updateProgress(
          id,
          progress: progress,
          description: '${(progress * 100).toStringAsFixed(0)}% complete',
        );
      }
    });
    _timers.add(timer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center Example'),
        actions: [
          NotificationBellButton(
            controller: _notifications,
            iconColor: Theme.of(context).colorScheme.onSurface,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Kick off fake "downloads" — progress ticks while you stay '
              'on this page or navigate away. Open the bell to see them.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Start download'),
                  onPressed: () => _startFakeDownload(),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.error_outline),
                  label: const Text('Start download (will fail)'),
                  onPressed: () => _startFakeDownload(willFail: true),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear completed'),
                  onPressed: _notifications.clearCompleted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:codifyiq_brightness_button/codifyiq_brightness_button.dart';
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

  /// Whether new downloads report an indeterminate (unknown-duration)
  /// progress bar rather than a determinate percentage.
  bool _indeterminate = false;

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
    final fileName = 'file_$_taskCounter.zip';
    final indeterminate = _indeterminate;
    _notifications.start(
      id: id,
      title: 'Downloading $fileName',
      description: indeterminate ? 'Working…' : 'Starting…',
      // A null progress renders as an indeterminate spinner.
      progress: indeterminate ? null : 0,
    );

    if (indeterminate) {
      // Unknown-duration work: no progress ticks, just finish after a while.
      final ticksToFinish = 8 + _random.nextInt(8);
      var ticks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 400), (t) {
        ticks += 1;
        if (ticks >= ticksToFinish) {
          t.cancel();
          _timers.remove(t);
          _finishDownload(id, fileName, willFail: willFail);
        }
      });
      _timers.add(timer);
      return;
    }

    double progress = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      progress += 0.05 + _random.nextDouble() * 0.1;
      if (progress >= 1.0) {
        t.cancel();
        _timers.remove(t);
        _finishDownload(id, fileName, willFail: willFail);
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

  void _finishDownload(String id, String fileName, {required bool willFail}) {
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
        description: 'Saved to Downloads/$fileName',
        action: NotificationItemAction(
          label: 'Open',
          onPressed: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Opening $fileName')),
            );
          },
        ),
      );
    }
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
          const BrightnessButton(),
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 4,
              children: [
                _ModeCheckbox(
                  label: 'Determinate',
                  selected: !_indeterminate,
                  onSelected: () => setState(() => _indeterminate = false),
                ),
                _ModeCheckbox(
                  label: 'Indeterminate',
                  selected: _indeterminate,
                  onSelected: () => setState(() => _indeterminate = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
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

/// A labelled checkbox used as a mutually-exclusive mode selector for the
/// determinate / indeterminate download toggle.
class _ModeCheckbox extends StatelessWidget {
  const _ModeCheckbox({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: selected,
            onChanged: (_) => onSelected(),
          ),
          Text(label),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

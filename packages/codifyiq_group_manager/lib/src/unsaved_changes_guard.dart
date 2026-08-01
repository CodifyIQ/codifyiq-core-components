import 'package:flutter/material.dart';

/// Blocks accidental dismissal of a modal that holds unsaved edits.
///
/// Internal: wrap a dialog or sheet body in this and pass [hasChanges]
/// recomputed on each build. While it is `true` every route-level dismissal —
/// barrier tap, system back, Escape, and any `Navigator.maybePop` from a Cancel
/// button — is intercepted and routed through a "Discard changes?" prompt; the
/// route only pops if the user confirms. While it is `false` dismissal behaves
/// exactly as before.
///
/// Drag-to-dismiss on a modal bottom sheet pops the route directly and cannot
/// be intercepted here, so hosts that use this guard inside a sheet must show
/// it with `enableDrag: false` (and no drag handle, which is independently
/// draggable when `enableDrag` is false).
class UnsavedChangesGuard extends StatelessWidget {
  /// Creates an [UnsavedChangesGuard].
  ///
  /// [hasChanges] is whether the wrapped modal currently holds edits worth
  /// confirming before discarding. [child] is the modal body.
  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.child,
  });

  /// Whether the wrapped modal holds unsaved edits.
  final bool hasChanges;

  /// The modal body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard(context) && navigator.mounted) {
          navigator.pop(result);
        }
      },
      child: child,
    );
  }

  static Future<bool> _confirmDiscard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

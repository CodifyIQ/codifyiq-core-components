import 'package:flutter/foundation.dart';

/// Lifecycle status of a [NotificationItem].
///
/// - [running]: the task is in progress; a progress bar is shown.
/// - [success]: the task completed successfully.
/// - [error]: the task finished with a failure.
enum NotificationItemStatus { running, success, error }

/// An optional labeled action attached to a [NotificationItem].
///
/// Rendered as a trailing button on the notification row (for example,
/// "Open" on a completed download or "Retry" on a failure).
@immutable
class NotificationItemAction {
  /// Creates a [NotificationItemAction].
  const NotificationItemAction({required this.label, required this.onPressed});

  /// Short label shown on the action button.
  final String label;

  /// Invoked when the user taps the action button.
  final VoidCallback onPressed;
}

/// A single notification entry tracked by a
/// [NotificationCenterController].
///
/// Items are immutable; the controller produces new copies via [copyWith]
/// whenever their state changes.
@immutable
class NotificationItem {
  /// Creates a [NotificationItem].
  const NotificationItem({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.progress,
    this.onTap,
    this.action,
    this.seen = false,
  });

  /// Stable identifier used by the controller to update or dismiss the item.
  final String id;

  /// Primary label shown on the row (e.g. "Downloading invoice.pdf").
  final String title;

  /// Optional secondary line shown beneath the title.
  final String? description;

  /// Current lifecycle status.
  final NotificationItemStatus status;

  /// Progress in the inclusive range `[0.0, 1.0]`, or `null` for an
  /// indeterminate progress bar.
  ///
  /// Only consulted when [status] is [NotificationItemStatus.running].
  final double? progress;

  /// When the item was first created.
  final DateTime createdAt;

  /// When the item was last updated.
  final DateTime updatedAt;

  /// Invoked when the user taps the row body. May be `null`.
  final VoidCallback? onTap;

  /// Optional trailing action (e.g. "Open" / "Retry").
  final NotificationItemAction? action;

  /// Whether the user has seen this item since its last update.
  ///
  /// Drives the unread-badge count on the bell button. The controller
  /// marks every item seen when the panel opens.
  final bool seen;

  /// Whether the item is still running.
  bool get isRunning => status == NotificationItemStatus.running;

  /// Whether the item has finished (success or error).
  bool get isCompleted => !isRunning;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass [clearProgress], [clearDescription], [clearOnTap], or
  /// [clearAction] to explicitly reset those nullable fields to `null`.
  NotificationItem copyWith({
    String? title,
    String? description,
    NotificationItemStatus? status,
    double? progress,
    DateTime? updatedAt,
    VoidCallback? onTap,
    NotificationItemAction? action,
    bool? seen,
    bool clearProgress = false,
    bool clearDescription = false,
    bool clearOnTap = false,
    bool clearAction = false,
  }) {
    return NotificationItem(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      onTap: clearOnTap ? null : (onTap ?? this.onTap),
      action: clearAction ? null : (action ?? this.action),
      seen: seen ?? this.seen,
    );
  }
}

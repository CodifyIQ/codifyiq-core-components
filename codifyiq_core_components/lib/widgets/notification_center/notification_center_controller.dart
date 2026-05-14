import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'notification_item.dart';

class _Bus extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// State container for a notification center.
///
/// Holds an ordered list of [NotificationItem]s and exposes mutation methods
/// for the typical lifecycle of a long-running, user-initiated task:
///
/// 1. Call [start] when work begins — adds a running item.
/// 2. Call [updateProgress] as the task progresses.
/// 3. Call [complete] or [fail] when the task finishes.
/// 4. The user can [dismiss] individual completed items or [clearCompleted]
///    to remove all finished items at once.
///
/// This controller is **UI-only**: it does not start, schedule, or cancel any
/// real background work. Consumers drive it from their own task layer
/// (HTTP clients, isolates, platform background workers, etc.).
///
/// Newest items are stored first. The controller exposes three listenables
/// for efficient rebuilds:
///
/// - The controller itself ([Listenable] via [ChangeNotifier]) fires on every
///   change. Suitable for external consumers that just want to know
///   "something happened".
/// - [structureListenable] fires only when items are added, removed, or
///   transition between running / succeeded / failed sections. Layout-level
///   widgets should listen here.
/// - [itemListenable] returns a per-item [ValueListenable] that fires only
///   when that specific item is updated (e.g. progress ticks). Row widgets
///   should listen here so a single item's progress tick does not rebuild
///   every other row.
class NotificationCenterController extends ChangeNotifier {
  /// Creates an empty controller.
  ///
  /// Pass a custom [clock] to override [DateTime.now] in tests.
  NotificationCenterController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final List<NotificationItem> _items = <NotificationItem>[];
  final _Bus _structure = _Bus();
  final Map<String, ValueNotifier<NotificationItem>> _itemNotifiers =
      <String, ValueNotifier<NotificationItem>>{};
  int _observerCount = 0;

  /// Unmodifiable view of every tracked item, newest first.
  List<NotificationItem> get items => List.unmodifiable(_items);

  /// Running items, newest first.
  List<NotificationItem> get running =>
      _items.where((i) => i.status == NotificationItemStatus.running).toList();

  /// Successfully completed items, newest first.
  List<NotificationItem> get succeeded =>
      _items.where((i) => i.status == NotificationItemStatus.success).toList();

  /// Failed items, newest first.
  List<NotificationItem> get failed =>
      _items.where((i) => i.status == NotificationItemStatus.error).toList();

  /// Number of items the user has not yet seen — drives the bell badge.
  int get unreadCount => _items.where((i) => !i.seen).length;

  /// Whether any items are currently running.
  bool get hasRunning => _items.any((i) => i.isRunning);

  /// Whether the controller is currently empty.
  bool get isEmpty => _items.isEmpty;

  /// Whether at least one widget has registered as actively displaying these
  /// notifications via [beginObserving].
  ///
  /// While observed, items added or updated are marked seen immediately so
  /// the bell badge stays at zero — the user is already looking at them.
  bool get isObserved => _observerCount > 0;

  /// Fires only when items are added, removed, reordered, or transition
  /// between running / succeeded / failed sections.
  ///
  /// Layout-level widgets that render the list structure should listen here
  /// rather than to the controller itself, so per-item content updates (like
  /// progress ticks) do not trigger a full panel rebuild.
  Listenable get structureListenable => _structure;

  /// Returns a [ValueListenable] that fires only when the item with [id] is
  /// updated.
  ///
  /// Returns `null` if no such item is currently tracked. Row widgets should
  /// wrap their contents in a [ValueListenableBuilder] driven by this so that
  /// a single item's progress tick rebuilds only its own row.
  ValueListenable<NotificationItem>? itemListenable(String id) =>
      _itemNotifiers[id];

  /// Looks up an item by [id], or returns `null` if absent.
  NotificationItem? itemById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Register interest in observing notifications.
  ///
  /// Increments an internal observer count. While the count is non-zero, any
  /// new or updated item is automatically marked seen, so the bell badge
  /// remains at zero while the user is actively viewing the panel. Calls
  /// [markAllSeen] eagerly so existing unread items also clear.
  ///
  /// The default [NotificationCenterPanel] manages this automatically through
  /// its widget lifecycle; consumers embedding the panel themselves should
  /// pair every [beginObserving] with a matching [endObserving].
  void beginObserving() {
    _observerCount++;
    markAllSeen();
  }

  /// Release a previous [beginObserving] call.
  ///
  /// Decrements the observer count, clamped at zero.
  void endObserving() {
    if (_observerCount > 0) _observerCount--;
  }

  /// Adds a new running item.
  ///
  /// If an item with [id] is already tracked, it is replaced — but the
  /// existing item's [NotificationItem.createdAt] timestamp is preserved so
  /// downstream ordering / analytics remain stable. To truly start fresh
  /// (and reset `createdAt`), call [dismiss] first.
  ///
  /// [progress] may be `null` for an indeterminate bar.
  void start({
    required String id,
    required String title,
    String? description,
    double? progress,
    VoidCallback? onTap,
  }) {
    final now = _clock();
    NotificationItem? existing;
    for (final i in _items) {
      if (i.id == id) {
        existing = i;
        break;
      }
    }
    final item = NotificationItem(
      id: id,
      title: title,
      description: description,
      status: NotificationItemStatus.running,
      progress: progress,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      onTap: onTap,
      seen: isObserved,
    );
    _items.removeWhere((i) => i.id == id);
    _items.insert(0, item);
    final notifier = _itemNotifiers[id];
    if (notifier == null) {
      _itemNotifiers[id] = ValueNotifier<NotificationItem>(item);
    } else {
      notifier.value = item;
    }
    _structure.fire();
    notifyListeners();
  }

  /// Updates progress (and optionally [title] / [description]) on a running
  /// item.
  ///
  /// Pass [clearProgress] to reset the progress bar to indeterminate (useful
  /// for transitioning a download into a "verifying…" phase, for example).
  ///
  /// Does nothing if the item is not found or has already completed.
  void updateProgress(
    String id, {
    double? progress,
    String? title,
    String? description,
    bool clearProgress = false,
  }) {
    final index = _indexOf(id);
    if (index == -1) return;
    final current = _items[index];
    if (!current.isRunning) return;
    final updated = current.copyWith(
      progress: progress,
      title: title,
      description: description,
      updatedAt: _clock(),
      seen: isObserved,
      clearProgress: clearProgress,
    );
    _items[index] = updated;
    _itemNotifiers[id]?.value = updated;
    // Item content changed but section structure did not — fire the item
    // notifier only and let row widgets rebuild themselves.
    notifyListeners();
  }

  /// Transitions an item to [NotificationItemStatus.success].
  ///
  /// Pass [description], [action], or [onTap] to update the row's
  /// presentation in its completed form.
  void complete(
    String id, {
    String? description,
    NotificationItemAction? action,
    VoidCallback? onTap,
  }) {
    _finish(
      id,
      NotificationItemStatus.success,
      description: description,
      action: action,
      onTap: onTap,
    );
  }

  /// Transitions an item to [NotificationItemStatus.error].
  void fail(
    String id, {
    String? description,
    NotificationItemAction? action,
    VoidCallback? onTap,
  }) {
    _finish(
      id,
      NotificationItemStatus.error,
      description: description,
      action: action,
      onTap: onTap,
    );
  }

  void _finish(
    String id,
    NotificationItemStatus status, {
    String? description,
    NotificationItemAction? action,
    VoidCallback? onTap,
  }) {
    final index = _indexOf(id);
    if (index == -1) return;
    final isSuccess = status == NotificationItemStatus.success;
    final updated = _items[index].copyWith(
      status: status,
      description: description,
      action: action,
      onTap: onTap,
      progress: isSuccess ? 1.0 : null,
      clearProgress: !isSuccess,
      updatedAt: _clock(),
      seen: isObserved,
    );
    _items[index] = updated;
    _itemNotifiers[id]?.value = updated;
    // Section transition (running → succeeded / failed) — fire structure.
    _structure.fire();
    notifyListeners();
  }

  /// Removes the item with [id], if present.
  void dismiss(String id) {
    final before = _items.length;
    _items.removeWhere((i) => i.id == id);
    final notifier = _itemNotifiers.remove(id);
    notifier?.dispose();
    if (_items.length != before) {
      _structure.fire();
      notifyListeners();
    }
  }

  /// Removes every completed (success or error) item.
  void clearCompleted() {
    final removedIds = <String>[];
    final remaining = <NotificationItem>[];
    for (final i in _items) {
      if (i.isCompleted) {
        removedIds.add(i.id);
      } else {
        remaining.add(i);
      }
    }
    if (removedIds.isEmpty) return;
    for (final id in removedIds) {
      _itemNotifiers.remove(id)?.dispose();
    }
    _items
      ..clear()
      ..addAll(remaining);
    _structure.fire();
    notifyListeners();
  }

  /// Removes every item, including running ones.
  void clearAll() {
    if (_items.isEmpty) return;
    for (final notifier in _itemNotifiers.values) {
      notifier.dispose();
    }
    _itemNotifiers.clear();
    _items.clear();
    _structure.fire();
    notifyListeners();
  }

  /// Marks every item as seen, zeroing the unread badge.
  void markAllSeen() {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].seen) {
        final updated = _items[i].copyWith(seen: true);
        _items[i] = updated;
        _itemNotifiers[updated.id]?.value = updated;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  int _indexOf(String id) {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].id == id) return i;
    }
    return -1;
  }

  @override
  void dispose() {
    _structure.dispose();
    for (final notifier in _itemNotifiers.values) {
      notifier.dispose();
    }
    _itemNotifiers.clear();
    super.dispose();
  }
}

/// Provides an ambient [NotificationCenterController] to descendants.
///
/// Wrap a subtree with [NotificationCenterScope] so any widget below can
/// reach the controller without prop-drilling:
///
/// ```dart
/// NotificationCenterScope(
///   controller: myController,
///   child: MyApp(),
/// );
///
/// // Anywhere in the subtree:
/// NotificationCenterScope.of(context).start(id: 'x', title: 'Working');
/// ```
class NotificationCenterScope
    extends InheritedNotifier<NotificationCenterController> {
  /// Creates a scope hosting [controller].
  const NotificationCenterScope({
    super.key,
    required NotificationCenterController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Returns the nearest enclosing controller.
  ///
  /// By default the calling element is registered as a dependency and will
  /// rebuild whenever the controller fires. Pass `listen: false` to look up
  /// the controller without subscribing — useful when the caller already
  /// wraps its build in a [ListenableBuilder] / [ValueListenableBuilder].
  ///
  /// Throws a [FlutterError] when no scope is found.
  static NotificationCenterController of(
    BuildContext context, {
    bool listen = true,
  }) {
    final controller = maybeOf(context, listen: listen);
    assert(
      controller != null,
      'No NotificationCenterScope found in the widget tree.',
    );
    return controller!;
  }

  /// Like [of] but returns `null` when no scope is present.
  static NotificationCenterController? maybeOf(
    BuildContext context, {
    bool listen = true,
  }) {
    if (listen) {
      return context
          .dependOnInheritedWidgetOfExactType<NotificationCenterScope>()
          ?.notifier;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<NotificationCenterScope>();
    final widget = element?.widget as NotificationCenterScope?;
    return widget?.notifier;
  }
}

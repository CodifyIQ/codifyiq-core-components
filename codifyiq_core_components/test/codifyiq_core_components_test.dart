import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationCenterController', () {
    test('start adds a running item and lights the bell', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working');

      expect(controller.items, hasLength(1));
      expect(controller.running, hasLength(1));
      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.running,
      );
      expect(controller.homogeneousCount, 1);
    });

    test('complete transitions a running item to success', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working');
      controller.complete('a', description: 'Done');

      final item = controller.itemById('a')!;
      expect(item.status, NotificationItemStatus.success);
      expect(item.description, 'Done');
      expect(item.progress, 1.0);
      expect(controller.running, isEmpty);
      expect(controller.succeeded, hasLength(1));
    });

    test('fail clears progress (no spurious 1.0)', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working', progress: 0.4);
      controller.fail('a', description: 'Boom');

      final item = controller.itemById('a')!;
      expect(item.status, NotificationItemStatus.error);
      expect(item.progress, isNull);
    });

    test('markAllSeen quiets the bell once completions are acknowledged', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working');
      controller.complete('a');

      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.success,
      );
      controller.markAllSeen();
      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.none,
      );
    });

    test('markAllSeen does NOT quiet the bell while items are still running', () {
      // "Seen" gates notification events (success/error), not current state.
      // A running task must keep the bell lit even after the user peeked.
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working');
      controller.markAllSeen();

      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.running,
      );
      expect(controller.homogeneousCount, 1);
    });

    test('failed items take priority over running in aggregate', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working');
      controller.start(id: 'b', title: 'Working');
      controller.fail('b');

      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.error,
      );
      expect(controller.homogeneousCount, isNull);
    });

    test('running items keep the bell running even when a sibling completes', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working A');
      controller.start(id: 'b', title: 'Working B');
      controller.markAllSeen();
      // A finishes; B is still running. Bell must stay running, not flip
      // to success because A's unseen completion happens to be "newer."
      controller.complete('a');

      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.running,
      );
      // Mixed: 1 running + 1 unseen success → glyph, not a count.
      expect(controller.homogeneousCount, isNull);
    });

    test('a fresh failure re-lights the bell after items were seen', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working');
      controller.complete('a');
      controller.markAllSeen();
      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.none,
      );

      controller.start(id: 'b', title: 'Round two');
      controller.fail('b');
      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.error,
      );
    });

    test('clearCompleted removes finished items but keeps running ones', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Running');
      controller.start(id: 'b', title: 'Done');
      controller.complete('b');

      controller.clearCompleted();
      expect(controller.items, hasLength(1));
      expect(controller.itemById('a'), isNotNull);
      expect(controller.itemById('b'), isNull);
    });

    test('beginObserving keeps the bell quiet for completed work', () {
      final controller = NotificationCenterController();
      controller.beginObserving();
      controller.start(id: 'a', title: 'Working');
      controller.updateProgress('a', progress: 0.5);
      controller.complete('a');

      // Completion happened while observed → marked seen → bell quiet.
      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.none,
      );
      controller.endObserving();
    });

    test('endObserving releases observer; subsequent updates light bell', () {
      final controller = NotificationCenterController();
      controller.beginObserving();
      controller.endObserving();
      controller.start(id: 'a', title: 'Working');

      expect(
        controller.aggregateStatus,
        NotificationBellAggregateStatus.running,
      );
    });

    test('start preserves createdAt when replacing an existing item', () {
      var now = DateTime(2024, 1, 1, 10);
      final controller = NotificationCenterController(clock: () => now);
      controller.start(id: 'a', title: 'First');
      final first = controller.itemById('a')!;

      now = now.add(const Duration(hours: 1));
      controller.start(id: 'a', title: 'Second');
      final second = controller.itemById('a')!;

      expect(second.createdAt, first.createdAt);
      expect(second.updatedAt, isNot(first.updatedAt));
      expect(second.title, 'Second');
    });

    test('updateProgress(clearProgress: true) returns to indeterminate', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working', progress: 0.5);
      controller.updateProgress('a', clearProgress: true);

      expect(controller.itemById('a')!.progress, isNull);
    });

    test('itemListenable fires only when the targeted item updates', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'A');
      controller.start(id: 'b', title: 'B');

      var aFires = 0;
      var bFires = 0;
      controller.itemListenable('a')!.addListener(() => aFires++);
      controller.itemListenable('b')!.addListener(() => bFires++);

      controller.updateProgress('a', progress: 0.5);
      expect(aFires, 1);
      expect(bFires, 0);

      controller.updateProgress('b', progress: 0.5);
      expect(aFires, 1);
      expect(bFires, 1);
    });

    test('structureListenable fires on add/remove/transition only', () {
      final controller = NotificationCenterController();
      var fires = 0;
      controller.structureListenable.addListener(() => fires++);

      controller.start(id: 'a', title: 'Working');
      expect(fires, 1); // structural add

      controller.updateProgress('a', progress: 0.5);
      expect(fires, 1); // content-only, no structure fire

      controller.complete('a');
      expect(fires, 2); // running → succeeded transition

      controller.dismiss('a');
      expect(fires, 3); // removal
    });
  });
}

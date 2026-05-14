import 'package:codifyiq_core_components/codifyiq_core_components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationCenterController', () {
    test('start adds a running item and increments unread', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working');

      expect(controller.items, hasLength(1));
      expect(controller.running, hasLength(1));
      expect(controller.unreadCount, 1);
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

    test('markAllSeen clears the unread count', () {
      final controller = NotificationCenterController();
      controller.start(id: 'a', title: 'Working');
      controller.start(id: 'b', title: 'Working');

      expect(controller.unreadCount, 2);
      controller.markAllSeen();
      expect(controller.unreadCount, 0);
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

    test('beginObserving keeps the badge at zero for new updates', () {
      final controller = NotificationCenterController();
      controller.beginObserving();
      controller.start(id: 'a', title: 'Working');
      controller.updateProgress('a', progress: 0.5);
      controller.complete('a');

      expect(controller.unreadCount, 0);
      controller.endObserving();
    });

    test(
      'endObserving releases observer; subsequent updates increment unread',
      () {
        final controller = NotificationCenterController();
        controller.beginObserving();
        controller.endObserving();
        controller.start(id: 'a', title: 'Working');

        expect(controller.unreadCount, 1);
      },
    );

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

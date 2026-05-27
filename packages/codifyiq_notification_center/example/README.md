# codifyiq_notification_center example

```dart
import 'package:codifyiq_notification_center/codifyiq_notification_center.dart';
import 'package:flutter/material.dart';

final controller = NotificationCenterController();

// Drive the controller from your own task layer.
void uploadInvoice() {
  controller.start(id: 'job-1', title: 'Uploading invoice.pdf', progress: 0);
  controller.updateProgress('job-1', progress: 0.42);
  controller.complete('job-1', description: 'Saved to Documents/invoice.pdf');
}

// Surface the stoplight bell in your AppBar.
AppBar buildAppBar() {
  return AppBar(actions: [NotificationBellButton(controller: controller)]);
}
```

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

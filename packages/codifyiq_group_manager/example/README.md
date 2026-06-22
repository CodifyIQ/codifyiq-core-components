# codifyiq_group_manager example

```dart
import 'package:codifyiq_group_manager/codifyiq_group_manager.dart';
import 'package:flutter/material.dart';

final controller = GroupManagerController(
  groups: const [
    Group(id: 'admins', name: 'Administrators', icon: Icons.admin_panel_settings),
    Group(id: 'editors', name: 'Editors'),
  ],
);

// Catalog management:
Widget buildCatalog() => GroupManagerView(controller: controller);

// Assign groups to a user:
Widget buildAssignment(String userId) => ListenableBuilder(
  listenable: controller,
  builder: (context, _) => GroupAssignmentField(
    label: 'Groups',
    groups: controller.groups,
    selected: controller.groupsFor(userId),
    onChanged: (ids) => controller.setAssignments(userId, ids),
  ),
);
```

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).

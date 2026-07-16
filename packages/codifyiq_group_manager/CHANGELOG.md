## 1.2.0

* `GroupManagerController.assignMany` / `unassignMany` — add or remove groups across many principals in one call.
* `GroupBulkAssignmentDialog` — a picker for choosing groups to bulk-assign (`show`) or bulk-remove (`showRemoval`) across many principals; `showRemoval` accepts `lockedIds` to keep protected groups off the offered list.
* `maxVisibleChips` on `GroupAssignmentField` — cap visible chips, collapsing the rest behind "+N more".
* `singleLine` on `GroupAssignmentField` — a denser layout with the label, chips, and edit button on one row.
* `destructive` on `GroupPicker` — tints checkboxes and the confirm button with the error color, for pickers where checking a box means removing rather than keeping.
* `BulkSelectionBar` — a fixed-height selection toolbar (select all/none + bulk actions) for any list, with no dependency on `Group`.
* Fixed: `GroupPicker`'s action row could overflow with a long `confirmLabel`; it now wraps instead.

## 1.1.0

* `lockedIds` on `GroupAssignmentField`, `GroupPicker`, `GroupManagerView`, and `GroupListView` — designate permanent groups (e.g. an "Admin" group that always has access). When assigning, locked groups always show as chips bearing a lock glyph in place of the remove affordance (tooltip: "Required — can't be removed"), appear checked-and-disabled with the same lock glyph in the picker, and are always present in the resulting selection regardless of user interaction. In the catalog, a locked group's row shows a lock badge (tooltip: "Locked — can't be deleted") and offers no Delete action (it stays editable), so the permanent group your assignments depend on can't be deleted out from under them.
* `footer` on `GroupManagerView` and `GroupListView` — render a help or policy note beneath the last group that scrolls with the catalog.

## 1.0.0

* Initial release.
* `GroupManagerController` + `GroupManagerScope` — a UI-only state container for a flat catalog of authorization groups and their assignment to principals (no nested groups, no separate roles).
* `GroupManagerView` and `GroupListView` — drop-in Material 3 surfaces for creating, editing, and deleting groups, with cascade-unassign on delete and built-in search to filter long catalogs. `GroupManagerView` caps its content to a comfortable measure and centers it on large screens (configurable via `maxContentWidth`). Intercept persistence with `onCreate` / `onEdit` / `onDelete` to wire create/edit/delete to a backend before (or instead of) mutating the controller.
* `GroupColor` — group accents are theme-derived roles (`primary`/`secondary`/`tertiary`/`neutral`) resolved against the active `ColorScheme`, so they adapt to light/dark; a stable role is auto-assigned when none is set.
* `GroupAssignmentField` — assign one or more groups to a target via removable chips and a stationary edit button that opens a searchable picker (which both adds and removes membership). Customize the trigger's tooltip and glyph via `editLabel` / `editIcon` — e.g. an authorization icon when granting access rather than editing membership.
* `GroupPicker` — a searchable, multi-select group picker that adapts between a bottom sheet (compact widths) and a dialog (large screens).
* `GroupEditorDialog`, `GroupChip`, and `GroupAvatar` — composable building blocks for custom group-management screens.
